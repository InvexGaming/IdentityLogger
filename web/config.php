<?php
  //Configuration options
  return array(
    'identityloggersecret' => '',
    'authorizedips' => ['127.0.0.1'], /* list of authorized ips that can make updates */
    'trackingidcookiename' => 'identitylogger',
    'trackingidcookielength' => 64,
    'trackingidcookiepath' => '/',
    'usecloudflare' => false, /* set to true if using cloudflare */
    'db_servername' => '127.0.0.1',
    'db_username' => 'dbuser',
    'db_password' => 'dbpass',
    'db_dbname' => 'identitylogger',
    'db_charset' => 'utf8mb4',
    'rconpassword' => 'rconpassword'
  );
?>