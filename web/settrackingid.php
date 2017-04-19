<?php
  //Configuration Options
  $config = include('./config.php');
  
  //Get tracking id from GET parameter
  if (!empty($_GET['trackingid']) && strlen($_GET['trackingid']) == $config['trackingidcookielength']) {
    $trackingid = $_GET['trackingid'];
    
    //Set the required trackingid cookie
    setcookie($config['trackingidcookiename'], $trackingid, time() + (10 * 365 * 24 * 60 * 60), $config['trackingidcookiepath']);
  }
?>