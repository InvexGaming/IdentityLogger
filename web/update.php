<?php

  //Configuration Options
  $config = include('./config.php');
  
  use xPaw\SourceQuery\SourceQuery;
  require_once $config['sourcequerypath'];
  
  //Functions
  function generateTrackingId($length) {
    $characters = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    $charactersLength = strlen($characters);
    $randomString = '';
    for ($i = 0; $i < $length; $i++) {
        $randomString .= $characters[rand(0, $charactersLength - 1)];
    }
    return $randomString;
  }
  
  // Perform authorization checks
  $requestoriginip = $_SERVER['REMOTE_ADDR'];
  if ($config['usecloudflare'])
    $requestoriginip = $_SERVER["HTTP_CF_CONNECTING_IP"];
  
  if (!in_array($requestoriginip, $config['authorizedips'])) {
    exit ("Unauthorized IP access. Your IP is not in the authorized IP whitelist.");
  }
  
  if (empty($_SERVER['HTTP_IDENTITYLOGGER_SECRET'])) {
    exit ("IdentityLogger Secret Key was not provided.");
  }
  
  if ($_SERVER['HTTP_IDENTITYLOGGER_SECRET'] != $config['identityloggersecret']) {
    exit ("IdentityLogger Secret Key is invalid.");
  }
  
  //At this point request is authorized and we can continue
  
  //Connect to database at this stage
  $conn = mysqli_connect($config['db_servername'], $config['db_username'], $config['db_password'], $config['db_dbname']);
  
  if (!$conn)
    exit ("Failed to connect to IdentityLogger database.");
  
  //Set database charset
  mysqli_set_charset($conn, $config['db_charset']);
  
  //Check these parameters are provided at a minimum
  if (empty($_POST['steamid64']) || empty($_POST['ipaddress']) || empty($_POST['serverip']) || empty($_POST['serverport']))
    exit ("Some required parameters were not provided.");
  
  //Alias can either be empty or contain characters
  $alias = "";
  if (!empty($_POST['alias']))
    $alias = mysqli_real_escape_string($conn, $_POST['alias']);
  
  $steamid64 = $_POST['steamid64'];
  $ipaddress = $_POST['ipaddress'];
  $serverip = $_POST['serverip'];
  $serverport = $_POST['serverport'];
  
  //Check steamid64 to confirm its in a valid format
  if (!preg_match('/[0-9]{17}/', $steamid64))
    exit ("SteamID64 not in valid format.");
  
  //Check IP address for valid IPV4 format
  if (inet_pton($ipaddress) === false)
    exit ("IP address is not in valid format.");
  
  //Check server IP address for valid IPV4 format
  if (inet_pton($serverip) === false)
    exit ("Server IP address is not in valid format.");
  
  //All parameters are valid at this point
  
  //Get current epoch
  $epoch = date_timestamp_get(date_create()); //current epoch 
  
  //Delete old entries in the updaterequest table
  $query = "DELETE FROM updaterequests WHERE $epoch - timecreated > " . (60*1);
  $result = mysqli_query($conn, $query);
  
  //We will store identity ids which we will update
  $identitylist = [];
  $trackingid = ''; //the main tracking id
  
  //Obtain tracking ids from the updaterequest table if it exists
  //If such an entry does not exist, the client did not provide a tracking id
  
  $query = "SELECT trackingid FROM updaterequests WHERE steamid64 = $steamid64";
  $result = mysqli_query($conn, $query);
  
  if (mysqli_num_rows($result) > 0) {
    $row = mysqli_fetch_assoc($result);
    $providedtrackingid = $row["trackingid"];
    
    //Verify this tracking id is valid and exists in our database
    $query = "SELECT id, trackingid FROM identities WHERE trackingid = '$providedtrackingid'";
    $result = mysqli_query($conn, $query);
    
    if (mysqli_num_rows($result) > 0) {
      //Tracking id exists in database, it is valid
      $row = mysqli_fetch_assoc($result);
      $trackingid = $row["trackingid"];
      array_push($identitylist, $row["id"]);
    }
  }
  
  //If tracking id was not provided or invalid
  //Try to obtain an identity id by matching steamid64 or ip address
  //This may match multiple identities which will all be updated
  if (count($identitylist) == 0) {
    $query = "SELECT DISTINCT iden.id, iden.trackingid FROM identities iden LEFT JOIN steamids sid ON sid.identityid = iden.id LEFT JOIN ipaddresses ips ON ips.identityid = iden.id WHERE sid.steamid64 = $steamid64 OR INET_NTOA(ips.ip) = '$ipaddress' ORDER BY timecreated ASC";
    $result = mysqli_query($conn, $query);
    
    if (mysqli_num_rows($result) > 0) {
      while ($row = mysqli_fetch_assoc($result)) {
        //Set tracking id if its not set at this point
        //This will set the tracking id to the 'oldest' timecreated identity
        //Out of all of the multiple matches found
        if (empty($trackingid)) {
          $trackingid = $row["trackingid"];
        }
        
        array_push($identitylist, $row["id"]);
      }
    }
  }
  
  //If still no match found, this user has no identity
  //Make new one for them
  if (count($identitylist) == 0) {
    //Generate random tracking id
    $trackingid = generateTrackingId(64);
    
    $query = "INSERT INTO identities(trackingid, timecreated) VALUES ('$trackingid', $epoch)";
    $result = mysqli_query($conn, $query);
    
    array_push($identitylist, mysqli_insert_id($conn));
  }
  
  //We now have a list of identities to update
  foreach ($identitylist as $id) {
    //Insert or update steamid64
    $query = "INSERT INTO steamids(steamid64, joincount, firsttime, lasttime, identityid) VALUES ($steamid64, 1, $epoch, $epoch, $id) ON DUPLICATE KEY UPDATE joincount = joincount + 1, lasttime = $epoch";
    mysqli_query($conn, $query);
    
    //Insert or update ip address
    $query = "INSERT INTO ipaddresses(ip, joincount, firsttime, lasttime, identityid) VALUES (INET_ATON('$ipaddress'), 1, $epoch, $epoch, $id) ON DUPLICATE KEY UPDATE joincount = joincount + 1, lasttime = $epoch";
    mysqli_query($conn, $query);
    
    //Insert or update alias
    $query = "INSERT INTO aliases(name, joincount, firsttime, lasttime, identityid) VALUES ('$alias', 1, $epoch, $epoch, $id) ON DUPLICATE KEY UPDATE joincount = joincount + 1, lasttime = $epoch";
    mysqli_query($conn, $query);
  }
  
  //Send RCON back to server to update users tracking id based on their steamid64
  if (!empty($trackingid)) {
    define('SQ_SERVER_ADDR', $serverip);
    define('SQ_SERVER_PORT', $serverport);
    define('SQ_TIMEOUT', 1 );
    define('SQ_ENGINE', SourceQuery::SOURCE);
    
    $sourcequery = new SourceQuery();
    $rconcommand = 'sm_identitylogger_setclienttrackingid ' . $steamid64 . ' ' . $trackingid;
    
    try {
      $sourcequery->Connect(SQ_SERVER_ADDR, SQ_SERVER_PORT, SQ_TIMEOUT, SQ_ENGINE);
      $sourcequery->SetRconPassword($config['rconpassword']);
      $sourcequery->Rcon($rconcommand);
    }
    catch(Exception $e) {
      $sourcequery->Disconnect();
      exit ("Failed to send server RCON to set tracking id: " . $e->getMessage());
    }
    finally {
      $sourcequery->Disconnect();
    }
  }
  
  //Finished close mysql connections
  mysqli_close($conn);
  
?>