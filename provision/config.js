/*
 * This is the general configuration file
 * used to define postgres credentials
 * and the application port.
 *
 * Setup specific configuration (such as
 * mapnik version of redis host) are in
 * server.js ; the defaults provided there
 * are correct for the default setup.
 */
var config = {
    windshaft_port: 4000,
    postgres_host: '%DB_HOST%',
    postgres_port: 5432,
    postgres_user: '%DB_USER%',
    postgres_pass: '%DB_PASS%'
}
/* Don't remove this */
module.exports = config;
