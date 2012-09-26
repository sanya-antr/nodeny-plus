CREATE TABLE `admin` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `login` varchar(32) NOT NULL,
  `passwd` varchar(20) CHARACTER SET latin1 COLLATE latin1_bin NOT NULL,
  `name` tinytext NOT NULL,
  `post` tinytext NOT NULL,
  `privil` mediumtext NOT NULL,
  `usr_grps` varchar(1024) NOT NULL,
  `tunes` mediumtext NOT NULL,
  `ext` varchar(4) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `admin` (`login`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

CREATE TABLE `auth_log` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `uid` int(10) unsigned NOT NULL DEFAULT '0',
  `ip` int(10) unsigned NOT NULL DEFAULT '0',
  `start` int(10) unsigned NOT NULL DEFAULT '0',
  `end` int(10) unsigned NOT NULL DEFAULT '0',
  `properties` text NOT NULL,
  PRIMARY KEY (`id`),
  KEY `uid` (`uid`),
  KEY `start` (`start`),
  KEY `last` (`end`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

CREATE TABLE `auth_now` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `ip` varchar(15) NOT NULL,
  `start` int(10) unsigned NOT NULL DEFAULT '0',
  `last` int(10) unsigned NOT NULL DEFAULT '0',
  `properties` text NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ip` (`ip`),
  KEY `start` (`start`),
  KEY `last` (`last`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;


CREATE TABLE `cards` (
  `cid` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `cod` text NOT NULL,
  `money` float(6,2) NOT NULL DEFAULT '0.00',
  `tm_create` int(11) unsigned NOT NULL DEFAULT '0',
  `tm_end` int(11) unsigned NOT NULL DEFAULT '0',
  `tm_activate` int(11) unsigned NOT NULL DEFAULT '0',
  `adm_create` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `alive` enum('good','bad','stock','activated') NOT NULL DEFAULT 'good',
  `uid_activate` int(10) unsigned NOT NULL DEFAULT '0',
  `adm_owner` mediumint(9) NOT NULL DEFAULT '0',
  `adm_move` mediumint(8) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`cid`),
  KEY `r` (`adm_owner`),
  KEY `uid_activate` (`uid_activate`),
  KEY `adm_move` (`adm_move`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

CREATE TABLE `changes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `tbl` char(16) NOT NULL,
  `act` enum('create','edit','delete') NOT NULL DEFAULT 'create',
  `time` int(10) unsigned NOT NULL DEFAULT '0',
  `fid` bigint(20) unsigned NOT NULL DEFAULT '0',
  `adm` mediumint(9) unsigned NOT NULL DEFAULT '0',
  `old_data` longtext NOT NULL,
  `new_data` longtext NOT NULL,
  PRIMARY KEY (`id`),
  KEY `tbl` (`tbl`,`act`,`fid`),
  KEY `time` (`time`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

CREATE TABLE `config` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `time` int(11) NOT NULL DEFAULT '0',
  `data` mediumtext NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

CREATE TABLE `data0` (
  `id` bigint(20) unsigned NOT NULL auto_increment,
  `uid` int(10) unsigned NOT NULL,
  PRIMARY KEY  (`id`),
  KEY `uid` (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1;


CREATE TABLE `datasetup` (
  `id` smallint(8) unsigned NOT NULL AUTO_INCREMENT,
  `template` tinyint(3) unsigned NOT NULL,
  `type` tinyint(3) unsigned NOT NULL,
  `title` varchar(100) NOT NULL,
  `name` varchar(100) NOT NULL,
  `flags` varchar(32) NOT NULL,
  `param` text NOT NULL,
  `comment` text NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=MyISAM AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

CREATE TABLE `dictionary` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `type` text NOT NULL,
  `k` text NOT NULL,
  `v` text NOT NULL,
  UNIQUE KEY `type` (`type`(16),`k`(16)),
  KEY `street` (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

CREATE TABLE `ip_pool` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `ip` int(10) unsigned NOT NULL DEFAULT '0',
  `type` enum('static','dynamic','reserved') NOT NULL,
  `realip` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `release` int(10) unsigned NOT NULL DEFAULT '0',
  `uid` bigint(20) unsigned NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ip` (`ip`),
  KEY `type` (`type`),
  KEY `release` (`release`),
  KEY `uid` (`uid`),
  KEY `realip` (`realip`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `ip_mac` (
  `ip` bigint(20) NOT NULL default '0',
  `mac` char(12) NOT NULL,
  PRIMARY KEY  (`ip`),
  KEY `mac` (`mac`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `nets` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `preset` smallint(6) NOT NULL,
  `priority` int(11) NOT NULL,
  `class` tinyint(4) NOT NULL,
  `net` text NOT NULL,
  `port` smallint(5) unsigned NOT NULL,
  `comment` text NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

CREATE TABLE `pays` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `mid` mediumint(9) NOT NULL DEFAULT '0',
  `cash` float(8,2) NOT NULL DEFAULT '0.00',
  `time` int(11) NOT NULL,
  `creator` enum('other','admin','user','kernel') NOT NULL DEFAULT 'other',
  `creator_id` mediumint(9) NOT NULL,
  `creator_ip` int(10) unsigned NOT NULL,
  `reason` text NOT NULL,
  `comment` mediumtext NOT NULL,
  `category` smallint(6) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `mid` (`mid`),
  KEY `time` (`time`),
  KEY `category` (`category`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

CREATE TABLE `places` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `gpsX` float NOT NULL,
  `gpsY` float NOT NULL,
  `descr` text NOT NULL,
  `location` text NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

CREATE TABLE `services` (
  `service_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `module` varchar(64) NOT NULL,
  `category` varchar(64) NOT NULL,
  `title` varchar(64) NOT NULL,
  `description` varchar(512) NOT NULL,
  `grp_list` longtext NOT NULL,
  `price` float NOT NULL DEFAULT '0',
  `auto_renew` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `no_renew` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `param` longtext NOT NULL,
  PRIMARY KEY (`service_id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

CREATE TABLE `traflost` (
  `time` int(11) unsigned NOT NULL DEFAULT '0',
  `traf` int(10) unsigned NOT NULL DEFAULT '0',
  `collector` mediumint(9) unsigned NOT NULL DEFAULT '0',
  `ip1` int(10) unsigned NOT NULL DEFAULT '0',
  `ip2` int(10) unsigned NOT NULL DEFAULT '0',
  KEY `time` (`time`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

CREATE TABLE `user_grp` (
  `grp_id` mediumint(9) NOT NULL AUTO_INCREMENT,
  `grp_name` text NOT NULL,
  `grp_property` text NOT NULL,
  `grp_maxflow` int(11) NOT NULL,
  `grp_maxregflow` int(11) NOT NULL,
  `grp_nets` mediumtext NOT NULL,
  `grp_block_limit` float NOT NULL,
  PRIMARY KEY (`grp_id`)
) ENGINE=MyISAM AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

CREATE TABLE `users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(64) CHARACTER SET utf8 NOT NULL,
  `passwd` varchar(64) CHARACTER SET latin1 COLLATE latin1_bin NOT NULL,
  `grp` tinyint(4) unsigned NOT NULL DEFAULT '0',
  `contract` tinytext CHARACTER SET utf8 NOT NULL,
  `contract_date` int(10) unsigned NOT NULL,
  `state` enum('off','on') CHARACTER SET utf8 NOT NULL DEFAULT 'on',
  `balance` float(10,2) NOT NULL DEFAULT '0.00',
  `limit_balance` float(6,2) NOT NULL DEFAULT '0.00',
  `block_if_limit` tinyint(4) NOT NULL DEFAULT '0',
  `modify_time` int(11) NOT NULL DEFAULT '0',
  `fio` tinytext CHARACTER SET utf8 NOT NULL,
  `discount` tinyint(4) NOT NULL DEFAULT '0',
  `cstate` int(11) NOT NULL DEFAULT '0',
  `cstate_time` int(10) unsigned NOT NULL,
  `comment` text CHARACTER SET utf8 NOT NULL,
  `lstate` tinyint(4) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`),
  KEY `state` (`state`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

CREATE TABLE `users_services` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `uid` bigint(20) unsigned NOT NULL,
  `pay_id` bigint(20) unsigned NOT NULL,
  `service_id` int(10) unsigned NOT NULL,
  `tm_start` int(10) unsigned NOT NULL,
  `tm_end` int(10) unsigned NOT NULL,
  `next_service_id` int(10) unsigned NOT NULL DEFAULT '0',
  `tags` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `tm_end` (`tm_end`),
  KEY `uid` (`uid`),
  KEY `tags` (`tags`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

CREATE TABLE `users_trf` (
  `uid` int(11) unsigned NOT NULL DEFAULT '0',
  `submoney` float NOT NULL DEFAULT '0',
  `in1` bigint(20) NOT NULL DEFAULT '0',
  `out1` bigint(20) NOT NULL DEFAULT '0',
  `in2` bigint(20) NOT NULL DEFAULT '0',
  `out2` bigint(20) NOT NULL DEFAULT '0',
  `in3` bigint(20) NOT NULL DEFAULT '0',
  `out3` bigint(20) NOT NULL DEFAULT '0',
  `in4` bigint(20) NOT NULL DEFAULT '0',
  `out4` bigint(20) NOT NULL DEFAULT '0',
  `in5` bigint(20) NOT NULL DEFAULT '0',
  `out5` bigint(20) NOT NULL DEFAULT '0',
  `in6` bigint(20) NOT NULL DEFAULT '0',
  `out6` bigint(20) NOT NULL DEFAULT '0',
  `in7` bigint(20) NOT NULL DEFAULT '0',
  `out7` bigint(20) NOT NULL DEFAULT '0',
  `in8` bigint(20) NOT NULL DEFAULT '0',
  `out8` bigint(20) NOT NULL DEFAULT '0',
  `traf1` bigint(20) NOT NULL DEFAULT '0',
  `traf2` bigint(20) NOT NULL DEFAULT '0',
  `traf3` bigint(20) NOT NULL DEFAULT '0',
  `traf4` bigint(20) NOT NULL,
  `test` tinyint(4) NOT NULL DEFAULT '0',
  `actual` tinyint(4) NOT NULL DEFAULT '0',
  UNIQUE KEY `uid` (`uid`),
  KEY `changed` (`actual`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `users_limit` (
  `uid` int(10) unsigned NOT NULL,
  `traf1` bigint(20) unsigned NOT NULL default '0',
  `traf2` bigint(20) unsigned NOT NULL default '0',
  `traf3` bigint(20) unsigned NOT NULL default '0',
  `traf4` bigint(20) unsigned NOT NULL default '0',
  PRIMARY KEY  (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `webses_data` (
  `role` varchar(32) NOT NULL,
  `aid` mediumint(8) unsigned NOT NULL,
  `unikey` varchar(200) NOT NULL,
  `module` varchar(32) NOT NULL,
  `data` longtext NOT NULL,
  `created` int(10) unsigned NOT NULL,
  `expire` int(10) unsigned NOT NULL,
  UNIQUE KEY `unikey` (`unikey`),
  KEY `aid` (`aid`),
  KEY `expire` (`expire`),
  KEY `role` (`role`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `websessions` (
  `ses` varchar(200) NOT NULL,
  `uid` int(11) NOT NULL,
  `role` varchar(32) NOT NULL,
  `trust` tinyint(4) NOT NULL DEFAULT '1',
  `expire` int(10) unsigned NOT NULL,
  UNIQUE KEY `ses` (`ses`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

DROP VIEW IF EXISTS fullusers;
CREATE ALGORITHM=MERGE VIEW fullusers AS
    SELECT u.*, t.*,
    ((in1+in2+in3+in4+out1+out2+out3+out4)/1000000) AS traf,
    ((out1+out2+out3+out4)/1000000) AS traf_out,
    ((in1+in2+in3+in4)/1000000) AS traf_in
    FROM users u LEFT JOIN users_trf t ON u.id=t.uid;

DROP VIEW IF EXISTS v_auth_now;
CREATE ALGORITHM=MERGE VIEW v_auth_now AS 
    SELECT a.ip, u.id, u.balance, u.state,
        IF(u.block_if_limit>0, u.limit_balance, -9999) AS limit_money,
        t.in1, t.in2, t.in3, t.in4, t.out1, t.out2, t.out3, t.out4
    FROM auth_now a 
    JOIN ip_pool i ON a.ip = INET_NTOA(i.ip)
    JOIN users u ON i.uid = u.id
    LEFT JOIN users_trf t ON i.uid = t.uid;

DROP VIEW IF EXISTS v_ips;
CREATE ALGORITHM=MERGE VIEW v_ips AS
    SELECT
        IF(a.start IS NULL,0,1) AS auth, i.uid, INET_NTOA(i.ip) AS ip, i.ip AS ipn,
        i.type, i.`release`, (a.last -a.start) AS tm_auth, a.start, a.last, a.properties 
    FROM ip_pool i
    LEFT JOIN auth_now a ON INET_NTOA(i.ip) = a.ip
    WHERE i.uid<>0;

DROP VIEW IF EXISTS v_services;
CREATE ALGORITHM=MERGE VIEW v_services AS
    SELECT u.*, s.module, s.category, s.title, s.description, s.grp_list,
        s.price, s.auto_renew, s.no_renew, s.param 
    FROM users_services u LEFT JOIN services s ON u.service_id = s.service_id;

DROP FUNCTION IF EXISTS `get_ip`;
DELIMITER $$
CREATE FUNCTION `get_ip` ( user_id INTEGER UNSIGNED )  RETURNS VARCHAR(15) NO SQL
BEGIN
    DECLARE user_ip VARCHAR(15);
    DECLARE real_ip VARCHAR(15);

    SELECT INET_NTOA(ip) INTO user_ip FROM ip_pool
        WHERE uid = user_id AND type='static' LIMIT 1;
    IF( user_ip IS NOT NULL ) THEN RETURN user_ip; END IF;

    SELECT 1 INTO real_ip FROM users_services WHERE uid = user_id AND tags LIKE '%,realip,%';
    UPDATE ip_pool SET uid = user_id, `release` = UNIX_TIMESTAMP() + 300 
        WHERE (uid = 0 OR uid = user_id)
            AND type = 'dynamic'
            AND realip = IF(real_ip>0,1,0)
        ORDER BY uid DESC, id ASC LIMIT 1;

    SELECT INET_NTOA(ip) INTO user_ip FROM ip_pool
        WHERE uid = user_id LIMIT 1;
    RETURN user_ip;
END$$
DELIMITER ;


DROP PROCEDURE IF EXISTS `set_auth`;
DELIMITER $$
CREATE PROCEDURE `set_auth` (IN usr_ip VARCHAR(15), IN auth_properties VARCHAR(255))
BEGIN
  DECLARE usr_id INT;
  SELECT uid INTO usr_id FROM ip_pool WHERE INET_ATON(usr_ip) = ip LIMIT 1;

  IF( usr_id > 0 ) THEN

    INSERT INTO auth_now SET
        ip = usr_ip,
        properties = auth_properties,
        start = UNIX_TIMESTAMP(),
        last = UNIX_TIMESTAMP()
    ON DUPLICATE KEY UPDATE
        properties = auth_properties,
        last = UNIX_TIMESTAMP();

    UPDATE ip_pool SET `release` = UNIX_TIMESTAMP() + 300
        WHERE ip = INET_ATON(usr_ip) AND type = 'dynamic' LIMIT 1;
  END IF;
END$$
DELIMITER ;


DROP FUNCTION IF EXISTS `change_ippool`;
DELIMITER $$
CREATE FUNCTION `change_ippool` ( ip_start VARCHAR(15), ip_end VARCHAR(15), ip_type VARCHAR(32), ip_real TINYINT )
    RETURNS TINYINT NO SQL
BEGIN
    DECLARE ip1 INTEGER UNSIGNED;
    DECLARE ip2 INTEGER UNSIGNED;

    SELECT INET_ATON(ip_start), INET_ATON(ip_end) INTO ip1, ip2;

    IF( ip1 IS NULL OR 
        ip2 IS NULL OR
        ip1 > ip2 OR
        (ip2-ip1)>1023
    ) THEN
        RETURN NULL;
    END IF;

    WHILE ip1 <= ip2 DO
        INSERT INTO `ip_pool` SET `type` = ip_type, `ip` = ip1, `uid` = 0, `release` = 0, `realip` = ip_real
            ON DUPLICATE KEY UPDATE `type` = ip_type, `realip` = ip_real;
        SET ip1 = ip1 + 1;
    END WHILE;
    RETURN 1;
END$$
DELIMITER ;




DROP TRIGGER tr_users_2;
DROP TRIGGER tr_users_3;
DELIMITER $$
CREATE TRIGGER tr_users_2 BEFORE UPDATE ON users  
    FOR EACH ROW
    IF( SELECT id FROM admin WHERE login = NEW.name LIMIT 1 ) THEN SET NEW.name = OLD.name; END IF;

CREATE TRIGGER tr_users_3 BEFORE INSERT ON users  
    FOR EACH ROW
    IF( SELECT id FROM admin WHERE login = NEW.name LIMIT 1 ) THEN SET NEW.name = NULL; END IF;
$$
DELIMITER ;



INSERT INTO nets SET net='0.0.0.0/0', class='1', port='0', priority='1000', comment='';

INSERT admin SET login='admin', name='', post='', privil=',1,3,2,', usr_grps='', passwd=AES_ENCRYPT('33','BIGint');

ALTER TABLE `data0` ADD `_adr_street` VARCHAR(255) NOT NULL;
ALTER TABLE `data0` ADD INDEX (`_adr_street`);
INSERT INTO datasetup SET title='[01]Улица', name='_adr_street', type='8', param='street', template='0', flags='q', comment='';



CREATE USER 'nodeny'@'localhost' IDENTIFIED BY 'hardpass';
GRANT USAGE ON *.* TO 'nodeny'@'localhost' IDENTIFIED BY 'hardpass';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, ALTER, EXECUTE ON `nodeny`.* TO 'nodeny'@'localhost';