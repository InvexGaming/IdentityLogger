<?php
  //Configuration Options
  $config = include('./config.php');
  
  //Get tracking cookie for client
  $trackingid = "";
  if (isset($_COOKIE[$config['trackingidcookiename']]))
    $trackingid = $_COOKIE[$config['trackingidcookiename']];
  
  //Get provided client steamid64 via GET parameter
  $steamid64 = "";
  if (!empty($_GET['steamid64']))
    $steamid64 = $_GET['steamid64'];
  
  if (!empty($trackingid) && strlen($trackingid) == $config['trackingidcookielength'] && !empty($steamid64) && preg_match('/[0-9]{17}/', $steamid64)) {
    //Tracking Id is not empty
    //Write trackingid|steamid64|epoch to db
    
    $conn = mysqli_connect($config['db_servername'], $config['db_username'], $config['db_password'], $config['db_dbname']);
    
    if (!$conn)
      exit ("Failed to connect to IdentityLogger database.");
    
    //Set database charset
    mysqli_set_charset($conn, $config['db_charset']);
    
    //Get epoch
    $epoch = date_timestamp_get(date_create());
    
    $query = "INSERT INTO updaterequests(trackingid, steamid64, timecreated) VALUES('$trackingid', $steamid64, $epoch)";
    mysqli_query($conn, $query);
    
    mysqli_close($conn);
  }
?>