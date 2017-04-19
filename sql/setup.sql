-- Setup IdentityLogger
-- Warning: This will remove all current entries! Backup first.

DROP DATABASE IF EXISTS identitylogger;
CREATE DATABASE identitylogger
CHARACTER SET utf8mb4 /* MySQL 5.5.3+ */
COLLATE utf8mb4_unicode_ci;

USE identitylogger;

/*
* Lists of identities
*/
DROP TABLE IF EXISTS identities;
CREATE TABLE identities
(
  id INT NOT NULL AUTO_INCREMENT,
  trackingid VARCHAR(64), -- randomly generated tracking string based on cookie
  timecreated INT(11) NOT NULL, -- epoch timestamp
  comment VARCHAR(255), -- for extra info
  PRIMARY KEY (id)
);

/*
* Lists of steam ids
*/
DROP TABLE IF EXISTS steamids;
CREATE TABLE steamids
(
  steamid64 BIGINT(17) NOT NULL, -- steamid/community id in steamid64 format (17 integers)
  joincount INT NOT NULL DEFAULT 0, -- increment by 1 on every connection
  firsttime INT(11) NOT NULL, -- epoch timestamp
  lasttime INT(11) NOT NULL, -- epoch timestamp
  identityid INT,
  PRIMARY KEY (steamid64, identityid),
  FOREIGN KEY (identityid) REFERENCES identities(id)
);

/*
* Lists of ip addresses
*/
DROP TABLE IF EXISTS ipaddresses;
CREATE TABLE ipaddresses
(
  ip INT UNSIGNED NOT NULL, -- ip address of user in IPV4 format
  joincount INT NOT NULL DEFAULT 0, -- increment by 1 on every connection
  firsttime INT(11) NOT NULL, -- epoch timestamp
  lasttime INT(11) NOT NULL, -- epoch timestamp
  identityid INT,
  PRIMARY KEY (ip, identityid),
  FOREIGN KEY (identityid) REFERENCES identities(id)
);

/*
* Lists of string aliases
*/
DROP TABLE IF EXISTS aliases;
CREATE TABLE aliases
(
  name VARCHAR(64) NOT NULL, -- name or alias
  joincount INT NOT NULL DEFAULT 0, -- increment by 1 on every connection
  firsttime INT(11) NOT NULL, -- epoch timestamp
  lasttime INT(11) NOT NULL, -- epoch timestamp
  identityid INT,
  PRIMARY KEY (name, identityid),
  FOREIGN KEY (identityid) REFERENCES identities(id)
);

/*
* Temporary storage for trackingid|steamid64 combos
*/
DROP TABLE IF EXISTS updaterequests;
CREATE TABLE updaterequests
(
  id INT NOT NULL AUTO_INCREMENT,
  trackingid VARCHAR(64), -- randomly generated tracking string based on cookie
  steamid64 BIGINT(17) NOT NULL, -- steamid/community id in steamid64 format (17 integers)
  timecreated INT(11) NOT NULL, -- epoch timestamp
  PRIMARY KEY (id)
);
