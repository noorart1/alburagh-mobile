<?php
/**
 * Plugin Name: Alburagh Mobile API
 * Plugin URI: https://alburagh.com
 * Description: Custom REST API for Alburagh Flutter Mobile Application.
 * Version: 1.0.0
 * Author: Dar Alburagh
 * Author URI: https://alburagh.com
 * License: GPL2
 * Text Domain: alburagh-mobile-api
 */

if (!defined('ABSPATH')) {
    exit;
}

define('ALBURAGH_API_VERSION', '1.0.0');
define('ALBURAGH_API_PLUGIN_PATH', plugin_dir_path(__FILE__));
define('ALBURAGH_API_PLUGIN_URL', plugin_dir_url(__FILE__));

/*
|--------------------------------------------------------------------------
| Load Classes
|--------------------------------------------------------------------------
*/

require_once ALBURAGH_API_PLUGIN_PATH . 'includes/class-response.php';
require_once ALBURAGH_API_PLUGIN_PATH . 'includes/class-validator.php';
require_once ALBURAGH_API_PLUGIN_PATH . 'includes/class-security.php';
require_once ALBURAGH_API_PLUGIN_PATH . 'includes/class-user.php';
require_once ALBURAGH_API_PLUGIN_PATH . 'includes/class-auth.php';
require_once ALBURAGH_API_PLUGIN_PATH . 'includes/class-profile.php';
require_once ALBURAGH_API_PLUGIN_PATH . 'includes/class-api.php';

/*
|--------------------------------------------------------------------------
| Activation
|--------------------------------------------------------------------------
*/

register_activation_hook(__FILE__, function () {

    flush_rewrite_rules();

});

/*
|--------------------------------------------------------------------------
| Deactivation
|--------------------------------------------------------------------------
*/

register_deactivation_hook(__FILE__, function () {

    flush_rewrite_rules();

});

/*
|--------------------------------------------------------------------------
| Start Plugin
|--------------------------------------------------------------------------
*/

add_action('plugins_loaded', function () {

    new Alburagh_API();

});