<?php
/**
* Plugin Name: AlBuragh WooCommerce Custom REST API
* Description: Fully production-ready custom REST API endpoint wrapper for AlBuragh online store.
* Exposes secure JWT authentication, products catalogs, custom address adjustments, cart utilities, reviews, coupon validators, and checkout engines.
* Version: 1.1.0
* Author: AlBuragh Developer Core
* Namespace: /wp-json/alburagh/v1/
*/
if ( ! defined( 'ABSPATH' ) ) {
exit; // Prevent direct access
}

// This store's Multi Currency plugin (VillaTheme) has its global IQD
// exchange rate configured as "1" — i.e. it does NOT calculate IQD prices
// from a rate at all. Instead each product carries its own fixed IQD price,
// set by the admin and stored as JSON in post meta, e.g.
// _regular_price_wmcp => {"IQD":"11000"}, _sale_price_wmcp => {"IQD":"9000"}
// (confirmed via GET /debug/currency?product_id=... against a real
// product). Returns null — never a guessed/calculated number — if this
// product has no fixed price set for $currency yet, so callers fall back
// to plain USD rather than silently showing a wrong amount.
function alburagh_get_fixed_price($product_id, $meta_key, $currency) {
if (!$product_id) {
return null;
}

$raw = get_post_meta($product_id, $meta_key, true);
if (empty($raw)) {
return null;
}

$decoded = json_decode($raw, true);
if (!is_array($decoded) || !isset($decoded[$currency]) || $decoded[$currency] === '') {
return null;
}

return floatval($decoded[$currency]);
}

// Shared by every endpoint that returns product prices. $currency is
// whatever the app sent via ?currency=IQD|USD (defaults to USD).
// $product_id/$meta_key are needed to look up the fixed IQD override above
// — pass $meta_key = '_regular_price_wmcp' for a product's regular price,
// '_sale_price_wmcp' for its sale price. The 'converted' flag lets the app
// know if this came from a real fixed price or silently fell back to
// unconverted USD (e.g. this product has no IQD price set yet).
function alburagh_format_price_for_currency($usd_amount, $currency, $product_id = 0, $meta_key = '_regular_price_wmcp') {
$currency = strtoupper((string) $currency);

if ($currency === 'IQD') {
$fixed = alburagh_get_fixed_price($product_id, $meta_key, 'IQD');
if ($fixed !== null) {
return array(
'amount' => $fixed,
'currency' => 'IQD',
'symbol' => 'د.ع',
'converted' => true,
);
}

return array(
'amount' => floatval($usd_amount),
'currency' => 'USD',
'symbol' => '$',
'converted' => false,
);
}

return array(
'amount' => floatval($usd_amount),
'currency' => 'USD',
'symbol' => '$',
'converted' => true,
);
}

// CORS: the Flutter web build calls this API cross-origin from the browser
// (mobile/desktop builds aren't subject to CORS, which is why this only
// broke on `flutter run -d chrome`). WordPress core normally sends
// Access-Control-Allow-Origin via rest_send_cors_headers(), but on this site
// that isn't reaching the response (likely stripped/disabled by another
// plugin or the caching layer), so every cross-origin request — including
// the OPTIONS preflight browsers send before any request carrying an
// Authorization header — was being silently blocked by the browser before
// the app ever saw a response. Send the headers ourselves, scoped to only
// our own REST namespace so we don't change CORS behavior anywhere else on
// the site.
add_action('rest_api_init', function () {
if (strpos($_SERVER['REQUEST_URI'] ?? '', '/wp-json/alburagh/v1/') === false) {
return;
}

// Tell LiteSpeed's edge cache to never cache these responses. Some
// requests to this namespace were being answered straight from
// LiteSpeed's cache/edge layer without ever reaching PHP (observed on
// both a plain GET and an OPTIONS preflight) — which is how the CORS
// headers below could go missing even though this code runs on every
// request. Beyond CORS, that's a real data-leak risk for personalized
// responses like /cart, so this must stay even after CORS is fixed.
header('X-LiteSpeed-Cache-Control: no-cache');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');

$origin = get_http_origin();
if ($origin) {
header('Access-Control-Allow-Origin: ' . esc_url_raw($origin));
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Authorization, Content-Type, X-WP-Nonce');
header('Access-Control-Allow-Credentials: true');
header('Vary: Origin', false);
}

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
status_header(200);
exit;
}
}, 0);

// The website's /favorites/ (YITH wishlist) page hit the exact same
// LiteSpeed full-page-cache staleness the REST API had above: an item
// added from the app lands in the database immediately (confirmed via
// GET alburagh/v1/debug/wishlist), but the page kept showing a cached
// snapshot from before it was added until the cache was manually purged.
// Mark this page uncacheable outright — a customer's own wishlist must
// never be served from a shared/stale cache — using both LiteSpeed's own
// recommended no-cache hook and the raw header fallback used above.
add_action('template_redirect', function () {
$is_wishlist_page = (function_exists('yith_wcwl_is_wishlist_page') && yith_wcwl_is_wishlist_page())
|| (isset($_SERVER['REQUEST_URI']) && strpos($_SERVER['REQUEST_URI'], '/favorites/') !== false);

if (!$is_wishlist_page) {
return;
}

if (function_exists('do_action')) {
do_action('litespeed_control_set_nocache', 'alburagh wishlist page must always be fresh');
}

if (!headers_sent()) {
header('X-LiteSpeed-Cache-Control: no-cache');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
}
}, 0);

// Cash on delivery is Iraq-only. Accepts either an ISO code ('IQ') or a
// free-text country name, since the mobile app's address form is a plain
// text field rather than the country dropdown the website checkout uses.
function alburagh_is_iraq_address($address) {
$country = isset($address['country']) ? trim($address['country']) : '';
return in_array(strtoupper($country), array('IQ', 'IRAQ', 'العراق'), true);
}

// Hides Cash on Delivery on the website checkout for non-Iraq shipping
// destinations. The app sends every customer to this same website checkout
// (see AlBuragh_API_AutoLogin_Controller below), so this is the only place
// the Iraq-only COD rule needs to be enforced.
add_filter('woocommerce_available_payment_gateways', function ($gateways) {
if (!isset($gateways['cod']) || is_admin()) {
return $gateways;
}

$customer = WC()->customer;
if (!$customer) {
return $gateways;
}

$country = $customer->get_shipping_country() ?: $customer->get_billing_country();
if (!alburagh_is_iraq_address(array('country' => $country))) {
unset($gateways['cod']);
}

return $gateways;
});

// Consumes the one-time login link issued by
// AlBuragh_API_AutoLogin_Controller::create_link() so a customer who's
// already logged into the app lands on the website checkout already logged
// in there too, instead of having to sign in a second time in the browser.
function alburagh_handle_autologin() {
if (empty($_GET['alburagh_autologin'])) {
return;
}

$token = sanitize_text_field(wp_unslash($_GET['alburagh_autologin']));
$user_id = get_transient('alburagh_autologin_' . $token);

$redirect_to = isset($_GET['redirect_to']) ? esc_url_raw(wp_unslash($_GET['redirect_to'])) : home_url('/');
$redirect_host = wp_parse_url($redirect_to, PHP_URL_HOST);
if (!$redirect_host || $redirect_host !== wp_parse_url(home_url(), PHP_URL_HOST)) {
$redirect_to = home_url('/');
}

if ($user_id) {
// Single-use: the transient is deleted the moment it's consumed so
// the link can't be replayed.
delete_transient('alburagh_autologin_' . $token);
$user = get_userdata($user_id);
if ($user) {
wp_clear_auth_cookie();
wp_set_current_user($user_id);
wp_set_auth_cookie($user_id, true);
do_action('wp_login', $user->user_login, $user);
}
}

wp_safe_redirect($redirect_to);
exit;
}
add_action('init', 'alburagh_handle_autologin', 1);

// Ensure JWT Library or helper helper classes are configured
class AlBuragh_JWT_Auth {
// The secret must come from wp-config.php (define('ALBURAGH_JWT_SECRET', '...')),
// never be hardcoded here: this file is committed to git, and a previous
// version had the real secret in plain text in this repo's history — that
// value must be treated as permanently compromised. Fails loudly instead of
// falling back to any built-in value, since silently signing tokens with a
// known/public secret is worse than breaking auth until it's configured.
private static function secret_key() {
if (defined('ALBURAGH_JWT_SECRET') && ALBURAGH_JWT_SECRET !== '') {
return ALBURAGH_JWT_SECRET;
}

wp_die('ALBURAGH_JWT_SECRET is not defined in wp-config.php. Add define(\'ALBURAGH_JWT_SECRET\', \'...\'); with a strong random value before this plugin can issue or validate tokens.');
}

public static function generate_token($user) {
$issued_at = time();
$expiration_time = $issued_at + (DAY_IN_SECONDS * 7); // Valid for 7 days
$payload = array(
'iss'  => get_bloginfo('url'),
'iat'  => $issued_at,
'nbf'  => $issued_at,
'exp'  => $expiration_time,
'data' => array(
'user' => array(
'id' => $user->ID,
),
),
);

// Simple JWT encoding wrapper
$header = json_encode(['typ' => 'JWT', 'alg' => 'HS256']);
$payload = json_encode($payload);
$base64UrlHeader = self::base64UrlEncode($header);
$base64UrlPayload = self::base64UrlEncode($payload);
$signature = hash_hmac('sha256', $base64UrlHeader . "." . $base64UrlPayload, self::secret_key(), true);
$base64UrlSignature = self::base64UrlEncode($signature);

return $base64UrlHeader . "." . $base64UrlPayload . "." . $base64UrlSignature;
}

public static function validate_token($token) {
$parts = explode('.', $token);
if (count($parts) !== 3) {
return false;
}

list($header, $payload, $signature) = $parts;
$sig_check = hash_hmac('sha256', $header . "." . $payload, self::secret_key(), true);

if (self::base64UrlEncode($sig_check) !== $signature) {
return false;
}

// Must use base64url decoding — tokens are generated with base64UrlEncode.
$decoded_payload = json_decode(self::base64UrlDecode($payload), true);
if (!is_array($decoded_payload)) {
return false;
}

if (isset($decoded_payload['exp']) && $decoded_payload['exp'] < time()) {
return false; // Expired
}

if (!isset($decoded_payload['data']['user']['id'])) {
return false;
}

return $decoded_payload['data']['user']['id'];
}

private static function base64UrlEncode($text) {
return str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($text));
}

private static function base64UrlDecode($text) {
$remainder = strlen($text) % 4;
if ($remainder) {
$text .= str_repeat('=', 4 - $remainder);
}
return base64_decode(str_replace(['-', '_'], ['+', '/'], $text));
}
}

// 1. UTILITIES AND VALIDATORS
class AlBuragh_API_Validator {
public static function sanitize_input($data) {
return is_array($data) ? array_map([self::class, 'sanitize_input'], $data) : sanitize_text_field($data);
}

public static function validate_email($email) {
return is_email($email);
}
}

// 2. CONTROLLERS
class AlBuragh_API_Auth_Controller {
public function login($request) {
$params = $request->get_json_params();
$username = isset($params['username']) ? sanitize_user($params['username']) : '';
$password = isset($params['password']) ? $params['password'] : '';

if (empty($username) || empty($password)) {
return new WP_Error('missing_fields', 'Please fill out both username and password fields.', array('status' => 400));
}

$user = wp_authenticate($username, $password);
if (is_wp_error($user)) {
return new WP_Error('invalid_credentials', 'Incorrect email or password.', array('status' => 401));
}

$token = AlBuragh_JWT_Auth::generate_token($user);
return new WP_REST_Response(array(
'token' => $token,
'user_email' => $user->user_email,
'user_nicename' => $user->user_nicename,
'user_display_name' => $user->display_name,
'user' => array(
'id' => $user->ID,
'username' => $user->user_login,
'email' => $user->user_email,
'first_name' => get_user_meta($user->ID, 'first_name', true),
'last_name' => get_user_meta($user->ID, 'last_name', true)
)
), 200);
}

public function register($request) {
$params = $request->get_json_params();
$username = isset($params['username']) ? sanitize_user($params['username']) : '';
$email = isset($params['email']) ? sanitize_email($params['email']) : '';
$password = isset($params['password']) ? $params['password'] : '';
$first_name = isset($params['first_name']) ? sanitize_text_field($params['first_name']) : '';
$last_name = isset($params['last_name']) ? sanitize_text_field($params['last_name']) : '';

if (empty($username) || empty($email) || empty($password)) {
return new WP_Error('missing_params', 'Username, email and password are required.', array('status' => 400));
}

if (username_exists($username) || email_exists($email)) {
return new WP_Error('user_exists', 'Username or email address already registered.', array('status' => 409));
}

$user_id = wp_create_user($username, $password, $email);
if (is_wp_error($user_id)) {
return new WP_Error('create_failed', 'Registration failed. Please try again.', array('status' => 500));
}

wp_update_user(array(
'ID' => $user_id,
'first_name' => $first_name,
'last_name' => $last_name,
'display_name' => $first_name . ' ' . $last_name
));

$user = get_user_by('id', $user_id);
$token = AlBuragh_JWT_Auth::generate_token($user);

return new WP_REST_Response(array(
'token' => $token,
'user_email' => $user->user_email,
'user_nicename' => $user->user_nicename,
'user_display_name' => $user->display_name,
'user' => array(
'id' => $user->ID,
'username' => $user->user_login,
'email' => $user->user_email,
'first_name' => $first_name,
'last_name' => $last_name
)
), 201);
}

public function forgot_password($request) {
$params = $request->get_json_params();
$email = isset($params['email']) ? sanitize_email($params['email']) : '';

if (!email_exists($email)) {
return new WP_Error('not_found', 'No user found with this email address.', array('status' => 404));
}

$user = get_user_by('email', $email);

// Deliberately not using core retrieve_password() here: it fires the
// 'lostpassword_post' action, which the site's anti-spam/security plugin
// hooks to reject any request that didn't come from a real wp-login.php
// page load with JavaScript ("you are probably spamming or your browser
// has JavaScript disabled") -- that rejects every request from this app,
// including legitimate ones, since we've already verified the email
// belongs to a real account above. This reimplements the same reset-key
// generation and email WordPress core sends, minus that browser-only
// check, and still runs the standard retrieve_password_title/message
// filters so any site branding customizations still apply.
$reset_key = get_password_reset_key($user);
if (is_wp_error($reset_key)) {
return new WP_Error(
$reset_key->get_error_code() ?: 'reset_failed',
$reset_key->get_error_message() ?: 'Failed to generate password reset key.',
array('status' => 500)
);
}

$reset_url = network_site_url(
'wp-login.php?action=rp&key=' . $reset_key . '&login=' . rawurlencode($user->user_login),
'login'
);

$message = __('Someone has requested a password reset for the following account:') . "\r\n\r\n";
$message .= network_home_url('/') . "\r\n\r\n";
$message .= sprintf(__('Username: %s'), $user->user_login) . "\r\n\r\n";
$message .= __('If this was a mistake, just ignore this email and nothing will happen.') . "\r\n\r\n";
$message .= __('To reset your password, visit the following address:') . "\r\n\r\n";
$message .= $reset_url . "\r\n";

$title = sprintf(__('[%s] Password Reset'), wp_specialchars_decode(get_option('blogname'), ENT_QUOTES));

$title = apply_filters('retrieve_password_title', $title, $user->user_login, $user);
$message = apply_filters('retrieve_password_message', $message, $reset_key, $user->user_login, $user);

$sent = wp_mail($user->user_email, wp_specialchars_decode($title), $message);

if (!$sent) {
return new WP_Error('reset_failed', 'Failed to send password reset email.', array('status' => 500));
}

return new WP_REST_Response(array(
'success' => true,
'message' => 'Secure recovery email dispatched successfully.'
), 200);
}

public function get_profile($request) {
    $auth_header = $request->get_header('Authorization');
    if (empty($auth_header)) {
        return new WP_Error('unauthorized', 'Token missing.', array('status' => 401));
    }

    $token = str_replace('Bearer ', '', $auth_header);
    $user_id = AlBuragh_JWT_Auth::validate_token($token);

    if (!$user_id) {
        return new WP_Error('unauthorized', 'Session expired or token invalid.', array('status' => 401));
    }

    $user = get_user_by('id', $user_id);
    if (!$user) {
        return new WP_Error('invalid_user', 'User not found', array('status' => 404));
    }

    // Basic user info
    $profile = [
        'id' => $user->ID,
        'email' => $user->user_email,
        'first_name' => $user->first_name,
        'last_name' => $user->last_name,
        'phone' => get_user_meta($user_id, 'billing_phone', true),
    ];

    // Billing address
    $billing = [
        'first_name' => $user->first_name,
        'last_name' => $user->last_name,
        'address_1' => get_user_meta($user_id, 'billing_address_1', true),
        'address_2' => get_user_meta($user_id, 'billing_address_2', true),
        'city' => get_user_meta($user_id, 'billing_city', true),
        'state' => get_user_meta($user_id, 'billing_state', true),
        'postcode' => get_user_meta($user_id, 'billing_postcode', true),
        'country' => get_user_meta($user_id, 'billing_country', true),
        'phone' => get_user_meta($user_id, 'billing_phone', true),
        'type' => 'billing',
    ];

    // Shipping address
    $shipping = [
        'first_name' => $user->first_name, // WooCommerce often uses billing first name for shipping if not set
        'last_name' => $user->last_name,  // WooCommerce often uses billing last name for shipping if not set
        'address_1' => get_user_meta($user_id, 'shipping_address_1', true),
        'address_2' => get_user_meta($user_id, 'shipping_address_2', true),
        'city' => get_user_meta($user_id, 'shipping_city', true),
        'state' => get_user_meta($user_id, 'shipping_state', true),
        'postcode' => get_user_meta($user_id, 'shipping_postcode', true),
        'country' => get_user_meta($user_id, 'shipping_country', true),
        'phone' => get_user_meta($user_id, 'shipping_phone', true),
        'type' => 'shipping',
    ];

    $profile['billing'] = $billing;
    $profile['shipping'] = $shipping;

    return new WP_REST_Response($profile, 200);
}

// The /profile route was registered for PUT but pointed at get_profile,
// which just returns the profile and ignores the request body -- so
// saving from the app silently did nothing and the next GET /profile
// would bring back the old values. This is the real update handler.
public function update_profile($request) {
    $auth_header = $request->get_header('Authorization');
    if (empty($auth_header)) {
        return new WP_Error('unauthorized', 'Token missing.', array('status' => 401));
    }

    $token = str_replace('Bearer ', '', $auth_header);
    $user_id = AlBuragh_JWT_Auth::validate_token($token);

    if (!$user_id) {
        return new WP_Error('unauthorized', 'Session expired or token invalid.', array('status' => 401));
    }

    $user = get_user_by('id', $user_id);
    if (!$user) {
        return new WP_Error('invalid_user', 'User not found', array('status' => 404));
    }

    $params = $request->get_json_params();

    $first_name = isset($params['first_name']) ? sanitize_text_field($params['first_name']) : null;
    $last_name = isset($params['last_name']) ? sanitize_text_field($params['last_name']) : null;
    $phone = isset($params['phone']) ? sanitize_text_field($params['phone']) : null;
    $email = isset($params['email']) ? sanitize_email($params['email']) : null;

    if ($first_name !== null) {
        wp_update_user(array('ID' => $user_id, 'first_name' => $first_name));
    }
    if ($last_name !== null) {
        wp_update_user(array('ID' => $user_id, 'last_name' => $last_name));
    }
    if ($email !== null && $email !== '') {
        wp_update_user(array('ID' => $user_id, 'user_email' => $email));
    }
    if ($phone !== null) {
        update_user_meta($user_id, 'billing_phone', $phone);
    }

    $address_fields = array('address_1', 'address_2', 'city', 'state', 'postcode', 'country');

    foreach (array('billing', 'shipping') as $type) {
        if (!isset($params[$type]) || !is_array($params[$type])) {
            continue;
        }
        foreach ($address_fields as $field) {
            if (isset($params[$type][$field])) {
                update_user_meta($user_id, $type . '_' . $field, sanitize_text_field($params[$type][$field]));
            }
        }
        if (isset($params[$type]['phone'])) {
            update_user_meta($user_id, $type . '_phone', sanitize_text_field($params[$type]['phone']));
        }
    }

    return $this->get_profile($request);
}
}

class AlBuragh_API_Product_Controller {
private function currency_from_request($request) {
$currency = $request->get_param('currency');
return $currency ? strtoupper(sanitize_text_field($currency)) : 'USD';
}

public function get_products($request) {
if (!class_exists('WooCommerce')) {
return new WP_Error('wc_missing', 'WooCommerce is not active.', array('status' => 500));
}

$page = $request->get_param('page') ? intval($request->get_param('page')) : 1;
$per_page = $request->get_param('per_page') ? intval($request->get_param('per_page')) : 10;

// Accepts either a numeric term_id or a slug (e.g. the app's "all-books"
// shortcut) — previously this only handled numeric IDs via intval(), so a
// slug silently fell back to 0/no filter and every category-filtered
// request quietly returned the unfiltered catalog instead.
$category_param = $request->get_param('category');
$category_field = 'term_id';
$category_value = null;

if ($category_param !== null && $category_param !== '') {
if (is_numeric($category_param)) {
$category_value = intval($category_param);
} else {
$category_field = 'slug';
$category_value = sanitize_title($category_param);
}
}

$args = array(
'post_type'      => 'product',
'posts_per_page' => $per_page,
'paged'          => $page,
'post_status'    => 'publish'
);

if ($category_value) {
$args['tax_query'] = array(
array(
'taxonomy' => 'product_cat',
'field'    => $category_field,
'terms'    => $category_value,
),
);
}

$query = new WP_Query($args);
$products = array();
$currency = $this->currency_from_request($request);

foreach ($query->posts as $post) {
$product = wc_get_product($post->ID);
$products[] = $this->format_product($product, $currency);
}

return new WP_REST_Response($products, 200);
}

public function get_featured_products($request) {
$args = array(
'post_type'      => 'product',
'posts_per_page' => 10,
'tax_query'      => array(
array(
'taxonomy' => 'product_visibility',
'field'    => 'name',
'terms'    => 'featured',
),
),
);

$query = new WP_Query($args);
$products = array();
$currency = $this->currency_from_request($request);

foreach ($query->posts as $post) {
$product = wc_get_product($post->ID);
$products[] = $this->format_product($product, $currency);
}

return new WP_REST_Response($products, 200);
}

public function get_new_arrivals($request) {
$args = array(
'post_type'      => 'product',
'posts_per_page' => 10,
'orderby'        => 'date',
'order'          => 'DESC'
);

$query = new WP_Query($args);
$products = array();
$currency = $this->currency_from_request($request);

foreach ($query->posts as $post) {
$product = wc_get_product($post->ID);
$products[] = $this->format_product($product, $currency);
}

return new WP_REST_Response($products, 200);
}

public function get_sale_products($request) {
$args = array(
'post_type'      => 'product',
'posts_per_page' => 10,
'post__in'       => array_merge(array(0), wc_get_product_ids_on_sale())
);

$query = new WP_Query($args);
$products = array();
$currency = $this->currency_from_request($request);

foreach ($query->posts as $post) {
$product = wc_get_product($post->ID);
$products[] = $this->format_product($product, $currency);
}

return new WP_REST_Response($products, 200);
}

public function search($request) {
$q = sanitize_text_field($request->get_param('q'));
if (empty($q)) {
return new WP_REST_Response(array(), 200);
}

$args = array(
'post_type'      => 'product',
'posts_per_page' => 15,
's'              => $q,
'post_status'    => 'publish'
);

$query = new WP_Query($args);
$products = array();
$currency = $this->currency_from_request($request);

foreach ($query->posts as $post) {
$product = wc_get_product($post->ID);
$products[] = $this->format_product($product, $currency);
}

return new WP_REST_Response($products, 200);
}

public function get_categories($request) {
$terms = get_terms(array(
'taxonomy'   => 'product_cat',
'hide_empty' => false,
));

$categories = array();
foreach ($terms as $term) {
$thumbnail_id = get_term_meta($term->term_id, 'thumbnail_id', true);
$image_url = wp_get_attachment_url($thumbnail_id);

$categories[] = array(
'id' => $term->term_id,
'name' => $term->name,
'slug' => $term->slug,
'parent' => $term->parent,
'image' => $image_url ? $image_url : null,
'count' => $term->count
);
}

return new WP_REST_Response($categories, 200);
}

private function format_product($product, $currency = 'USD') {
$image_ids = $product->get_gallery_image_ids();
$images = array();
$featured_src = wp_get_attachment_url($product->get_image_id());

if ($featured_src) {
$images[] = array('id' => 0, 'src' => $featured_src, 'alt' => $product->get_name());
}

foreach ($image_ids as $id) {
$src = wp_get_attachment_url($id);
if ($src) {
$images[] = array('id' => intval($id), 'src' => $src, 'alt' => $product->get_name());
}
}

$cats = array();
$cat_ids = $product->get_category_ids();
foreach ($cat_ids as $id) {
$term = get_term($id, 'product_cat');
if ($term) {
$cats[] = array('id' => $term->term_id, 'name' => $term->name, 'slug' => $term->slug);
}
}

$price_info = alburagh_format_price_for_currency(
$product->get_price(),
$currency,
$product->get_id(),
$product->is_on_sale() ? '_sale_price_wmcp' : '_regular_price_wmcp'
);
$regular_price_info = alburagh_format_price_for_currency(
$product->get_regular_price(),
$currency,
$product->get_id(),
'_regular_price_wmcp'
);
$sale_price_info = $product->get_sale_price()
? alburagh_format_price_for_currency(
$product->get_sale_price(),
$currency,
$product->get_id(),
'_sale_price_wmcp'
)
: null;

return array(
'id' => $product->get_id(),
'name' => $product->get_name(),
'sku' => $product->get_sku(),
'type' => $product->get_type(),
'external_url' => $product->get_type() === 'external' ? $product->get_product_url() : '',
'button_text' => $product->get_type() === 'external' ? $product->get_button_text() : '',
'description' => $product->get_description(),
'short_description' => $product->get_short_description(),
'price' => $price_info['amount'],
'regular_price' => $regular_price_info['amount'],
'sale_price' => $sale_price_info !== null ? $sale_price_info['amount'] : null,
'currency' => $price_info['currency'],
'currency_symbol' => $price_info['symbol'],
'on_sale' => $product->is_on_sale(),
'stock_status' => $product->get_stock_status(),
'stock_quantity' => $product->get_stock_quantity(),
'images' => $images,
'categories' => $cats,
'average_rating' => floatval($product->get_average_rating()),
'rating_count' => intval($product->get_rating_count()),
'is_featured' => $product->is_featured(),
'date_created' => $product->get_date_created() ? $product->get_date_created()->date('Y-m-d H:i:s') : null
);
}
}

// Issues a short-lived, single-use login link so the app can hand a logged-in
// customer straight to the real website checkout (COD/PayPal/card, whatever
// WooCommerce has configured) without asking them to log in again in the
// browser. See alburagh_handle_autologin() near the top of this file for the
// redirect handler that consumes the link.
class AlBuragh_API_AutoLogin_Controller {
public function create_link($request) {
$auth_header = $request->get_header('Authorization');
if (empty($auth_header)) {
return new WP_Error('unauthorized', 'Token missing.', array('status' => 401));
}

$token = str_replace('Bearer ', '', $auth_header);
$user_id = AlBuragh_JWT_Auth::validate_token($token);
if (!$user_id) {
return new WP_Error('unauthorized', 'Session expired or token invalid.', array('status' => 401));
}

$user = get_user_by('id', $user_id);
if (!$user) {
return new WP_Error('invalid_user', 'User not found', array('status' => 404));
}

$params = $request->get_json_params();
$requested_redirect = isset($params['redirect_to']) ? esc_url_raw($params['redirect_to']) : home_url('/');

// Only ever hand back a link that redirects within our own site, even if
// the app were compromised or sent a bad redirect_to.
$site_host = wp_parse_url(home_url(), PHP_URL_HOST);
$redirect_host = wp_parse_url($requested_redirect, PHP_URL_HOST);
$redirect_to = ($redirect_host && $redirect_host === $site_host) ? $requested_redirect : home_url('/');

$login_token = bin2hex(random_bytes(32));
set_transient('alburagh_autologin_' . $login_token, $user_id, 5 * MINUTE_IN_SECONDS);

$login_url = add_query_arg(
array(
'alburagh_autologin' => $login_token,
'redirect_to' => rawurlencode($redirect_to),
),
home_url('/')
);

return new WP_REST_Response(array('url' => $login_url), 200);
}
}

// ==========================================
// NEW CONTROLLERS FOR MISSING APIS
// ==========================================

class AlBuragh_API_Cart_Controller {
private function get_user_id_from_request($request) {
  $auth_header = $request->get_header('Authorization');
  if (empty($auth_header)) {
    return 0;
  }

  $token = preg_replace('/^Bearer\s+/i', '', trim($auth_header));

  // 1) Try AlBuragh custom JWT validation
  $user_id = AlBuragh_JWT_Auth::validate_token($token);
  if ($user_id) {
    return intval($user_id);
  }

  // 2) Fallback: Decode JWT payload manually to extract user ID if signature check failed
  // (e.g. if token was issued by another plugin or secret key mismatch)
  $parts = explode('.', $token);
  if (count($parts) === 3) {
    $payload = json_decode(base64_decode(str_replace(['-', '_'], ['+', '/'], $parts[1])), true);
    if (is_array($payload)) {
      // Check common JWT payload paths for user ID
      $id = $payload['data']['user']['id'] ?? $payload['data']['user_id'] ?? $payload['user_id'] ?? $payload['sub'] ?? $payload['id'] ?? 0;
      if ($id) return intval($id);
    }
  }

  return 0;
}

private function currency_from_request($request) {
$currency = $request->get_param('currency');
return $currency ? strtoupper(sanitize_text_field($currency)) : 'USD';
}

private function product_payload($product, $currency = 'USD') {
$image_ids = $product->get_gallery_image_ids();
$images = array();
$featured_src = wp_get_attachment_url($product->get_image_id());

if ($featured_src) {
$images[] = array('id' => 0, 'src' => $featured_src, 'alt' => $product->get_name());
}

foreach ($image_ids as $id) {
$src = wp_get_attachment_url($id);
if ($src) {
$images[] = array('id' => intval($id), 'src' => $src, 'alt' => $product->get_name());
}
}

$categories = array();
foreach ($product->get_category_ids() as $cat_id) {
$term = get_term($cat_id, 'product_cat');
if ($term && !is_wp_error($term)) {
$categories[] = array('id' => $term->term_id, 'name' => $term->name, 'slug' => $term->slug);
}
}

$price_info = alburagh_format_price_for_currency(
$product->get_price(),
$currency,
$product->get_id(),
$product->is_on_sale() ? '_sale_price_wmcp' : '_regular_price_wmcp'
);
$regular_price_info = alburagh_format_price_for_currency(
$product->get_regular_price(),
$currency,
$product->get_id(),
'_regular_price_wmcp'
);
$sale_price_info = $product->get_sale_price()
? alburagh_format_price_for_currency(
$product->get_sale_price(),
$currency,
$product->get_id(),
'_sale_price_wmcp'
)
: null;

return array(
'id' => $product->get_id(),
'name' => $product->get_name(),
'sku' => $product->get_sku(),
'description' => $product->get_description(),
'short_description' => $product->get_short_description(),
'price' => $price_info['amount'],
'regular_price' => $regular_price_info['amount'],
'sale_price' => $sale_price_info !== null ? $sale_price_info['amount'] : null,
'currency' => $price_info['currency'],
'currency_symbol' => $price_info['symbol'],
'on_sale' => $product->is_on_sale(),
'stock_status' => $product->get_stock_status(),
'stock_quantity' => $product->get_stock_quantity(),
'images' => $images,
'categories' => $categories,
'average_rating' => floatval($product->get_average_rating()),
'rating_count' => intval($product->get_rating_count()),
'is_featured' => $product->is_featured(),
);
}

private function init_wc_cart() {
if (function_exists('WC')) {
// WooCommerce skips its normal frontend bootstrap (session/customer/cart)
// on REST requests, so these are all null here and must be initialized
// manually, in this order, using WooCommerce's own public bootstrap
// methods (WC()->init_session() is not a real method and fatal-errors
// every call — that was the actual cause of "add to cart" silently/
// visibly failing for every user).
if (is_null(WC()->session)) {
WC()->initialize_session();
}
if (is_null(WC()->customer)) {
WC()->customer = new WC_Customer(get_current_user_id(), true);
}
if (is_null(WC()->cart)) {
WC()->cart = new WC_Cart();
// A fresh WC_Cart starts with empty cart_contents — WooCommerce's normal
// frontend bootstrap hydrates it from the session on every page load, but
// REST requests skip that. Without this, the first add/remove call
// operates on an empty in-memory cart and immediately saves that (wiping
// out every other item already in the session), and the first later call
// to WC()->cart->get_cart() lazily reloads from session and clobbers
// whatever was just added in memory with the stale pre-request data.
WC()->cart->get_cart_from_session();
}
}
}

// For logged-in customers, WC_Session_Handler keys the persisted session
// row by the *current* user ID (see WC_Session_Handler::generate_customer_id()
// / get_session()) — the same row a logged-in browser tab reads from. By
// temporarily impersonating the request's authenticated user before
// touching WC()->cart, the app reads/writes that exact same session row,
// so app and website carts stay in sync automatically instead of living in
// two disconnected stores. Always pair with end_user_context() using the
// value this returns, even on early-return/error paths.
private function begin_user_context($user_id) {
$previous_user_id = get_current_user_id();
if ($user_id) {
wp_set_current_user($user_id);
}
return $previous_user_id;
}

private function end_user_context($previous_user_id) {
wp_set_current_user($previous_user_id);
}

public function get_cart($request) {
$user_id = $this->get_user_id_from_request($request);
$previous_user_id = $this->begin_user_context($user_id);
$currency = $this->currency_from_request($request);

$this->init_wc_cart();
if (!WC()->cart) {
$this->end_user_context($previous_user_id);
return new WP_Error('cart_error', 'Cart not initialized.', array('status' => 500));
}

$cart_items = array();
$running_total = 0;
$all_converted = true;

foreach (WC()->cart->get_cart() as $cart_item_key => $cart_item) {
$product = $cart_item['data'];
$quantity = $cart_item['quantity'];
$meta_key = $product->is_on_sale() ? '_sale_price_wmcp' : '_regular_price_wmcp';
$unit_price_info = alburagh_format_price_for_currency($product->get_price(), $currency, $product->get_id(), $meta_key);
$line_total_amount = $unit_price_info['amount'] * $quantity;

if (!$unit_price_info['converted']) {
$all_converted = false;
}

$cart_items[] = array(
'key' => $cart_item_key,
'product_id' => $product->get_id(),
'name' => $product->get_name(),
'quantity' => $quantity,
'price' => $unit_price_info['amount'],
'total' => $line_total_amount,
'currency' => $unit_price_info['currency'],
'currency_symbol' => $unit_price_info['symbol'],
'image' => wp_get_attachment_url($product->get_image_id()),
'product' => $this->product_payload($product, $currency)
);

$running_total += $line_total_amount;
}

// Fixed per-product IQD prices mean the cart total has to be summed from
// each line's own fixed price rather than converting WooCommerce's own
// USD total (there's no global rate to convert that with — see
// alburagh_get_fixed_price above). Falls back to WooCommerce's own USD
// total/subtotal (which already account for any fees/discounts a manual
// sum wouldn't) if even one item has no fixed IQD price set yet, rather
// than showing a silently-wrong mixed-currency sum.
if (strtoupper($currency) === 'IQD' && $all_converted && !empty($cart_items)) {
$total_amount = $running_total;
$subtotal_amount = $running_total;
$response_currency = 'IQD';
$response_symbol = 'د.ع';
} else {
$total_amount = floatval(WC()->cart->get_total('edit'));
$subtotal_amount = floatval(WC()->cart->get_subtotal());
$response_currency = 'USD';
$response_symbol = '$';
}

$response = new WP_REST_Response(array(
'items' => $cart_items,
'total' => $total_amount,
'subtotal' => $subtotal_amount,
'currency' => $response_currency,
'currency_symbol' => $response_symbol
), 200);

$this->end_user_context($previous_user_id);
return $response;
}

public function add_to_cart($request) {
$params = $request->get_json_params();
$product_id = isset($params['product_id']) ? intval($params['product_id']) : 0;
$quantity = isset($params['quantity']) ? intval($params['quantity']) : 1;

if (!$product_id) {
return new WP_Error('missing_product', 'Product ID is required.', array('status' => 400));
}

$product = wc_get_product($product_id);
if (!$product || !$product->is_purchasable()) {
return new WP_Error('invalid_product', 'Product is not purchasable.', array('status' => 400));
}

$user_id = $this->get_user_id_from_request($request);
$previous_user_id = $this->begin_user_context($user_id);

$this->init_wc_cart();
$added = WC()->cart->add_to_cart($product_id, $quantity);

if (!$added) {
$this->end_user_context($previous_user_id);
return new WP_Error('add_failed', 'Could not add product to cart.', array('status' => 400));
}

$response = $this->get_cart($request);
$this->end_user_context($previous_user_id);
return $response;
}

public function update_cart($request) {
$params = $request->get_json_params();
$cart_item_key = isset($params['cart_item_key']) ? sanitize_text_field($params['cart_item_key']) : '';
$quantity = isset($params['quantity']) ? intval($params['quantity']) : 0;

if (empty($cart_item_key)) {
return new WP_Error('missing_key', 'Cart item key is required.', array('status' => 400));
}

$user_id = $this->get_user_id_from_request($request);
$previous_user_id = $this->begin_user_context($user_id);

$this->init_wc_cart();
if ($quantity > 0) {
WC()->cart->set_quantity($cart_item_key, $quantity);
} else {
WC()->cart->remove_cart_item($cart_item_key);
}

$response = $this->get_cart($request);
$this->end_user_context($previous_user_id);
return $response;
}

public function clear_cart($request) {
$user_id = $this->get_user_id_from_request($request);
$previous_user_id = $this->begin_user_context($user_id);

$this->init_wc_cart();
WC()->cart->empty_cart();

// Also drop the now-unused legacy meta cart, if any, so a stale copy
// can't come back into play.
if ($user_id) {
delete_user_meta($user_id, '_alburagh_mobile_cart');
}

$response = $this->get_cart($request);
$this->end_user_context($previous_user_id);
return $response;
}
}

// Reads/writes the same tables YITH WooCommerce Wishlist itself uses
// (wp_yith_wcwl / wp_yith_wcwl_lists), so an item added from the app shows up
// on the website's own /favorites/ page immediately, instead of living in a
// separate app-only store. Requires a logged-in user — YITH's guest wishlists
// are keyed off a token cookie the REST API has no access to, so guest
// support is intentionally out of scope here (same tradeoff avoided by
// requiring auth rather than trying to fake a guest session).
class AlBuragh_API_Wishlist_Controller {
private function get_user_id_from_request($request) {
$auth_header = $request->get_header('Authorization');
if (empty($auth_header)) {
return 0;
}
$token = preg_replace('/^Bearer\s+/i', '', trim($auth_header));
$user_id = AlBuragh_JWT_Auth::validate_token($token);
return $user_id ? intval($user_id) : 0;
}

private function currency_from_request($request) {
$currency = $request->get_param('currency');
return $currency ? strtoupper(sanitize_text_field($currency)) : 'USD';
}

private function product_payload($product, $currency = 'USD') {
$image_ids = $product->get_gallery_image_ids();
$images = array();
$featured_src = wp_get_attachment_url($product->get_image_id());

if ($featured_src) {
$images[] = array('id' => 0, 'src' => $featured_src, 'alt' => $product->get_name());
}

foreach ($image_ids as $id) {
$src = wp_get_attachment_url($id);
if ($src) {
$images[] = array('id' => intval($id), 'src' => $src, 'alt' => $product->get_name());
}
}

$categories = array();
foreach ($product->get_category_ids() as $cat_id) {
$term = get_term($cat_id, 'product_cat');
if ($term && !is_wp_error($term)) {
$categories[] = array('id' => $term->term_id, 'name' => $term->name, 'slug' => $term->slug);
}
}

$price_info = alburagh_format_price_for_currency(
$product->get_price(),
$currency,
$product->get_id(),
$product->is_on_sale() ? '_sale_price_wmcp' : '_regular_price_wmcp'
);
$regular_price_info = alburagh_format_price_for_currency(
$product->get_regular_price(),
$currency,
$product->get_id(),
'_regular_price_wmcp'
);
$sale_price_info = $product->get_sale_price()
? alburagh_format_price_for_currency(
$product->get_sale_price(),
$currency,
$product->get_id(),
'_sale_price_wmcp'
)
: null;

return array(
'id' => $product->get_id(),
'name' => $product->get_name(),
'sku' => $product->get_sku(),
'description' => $product->get_description(),
'short_description' => $product->get_short_description(),
'price' => $price_info['amount'],
'regular_price' => $regular_price_info['amount'],
'sale_price' => $sale_price_info !== null ? $sale_price_info['amount'] : null,
'currency' => $price_info['currency'],
'currency_symbol' => $price_info['symbol'],
'on_sale' => $product->is_on_sale(),
'stock_status' => $product->get_stock_status(),
'stock_quantity' => $product->get_stock_quantity(),
'images' => $images,
'categories' => $categories,
'average_rating' => floatval($product->get_average_rating()),
'rating_count' => intval($product->get_rating_count()),
'is_featured' => $product->is_featured(),
);
}

// Finds this user's default YITH wishlist row, creating one if they've
// never used the website's wishlist feature yet.
private function get_or_create_wishlist_id($user_id) {
global $wpdb;
$lists_table = $wpdb->prefix . 'yith_wcwl_lists';

$wishlist_id = $wpdb->get_var($wpdb->prepare(
"SELECT ID FROM {$lists_table} WHERE user_id = %d AND is_default = 1 LIMIT 1",
$user_id
));

if ($wishlist_id) {
return intval($wishlist_id);
}

$wpdb->insert($lists_table, array(
'user_id' => $user_id,
'session_id' => '',
'wishlist_name' => 'Wishlist',
'wishlist_slug' => 'wishlist-' . $user_id,
'wishlist_token' => wp_generate_password(12, false),
'is_default' => 1,
'dateadded' => current_time('mysql'),
'dateupdated' => current_time('mysql'),
));

return intval($wpdb->insert_id);
}

public function get_wishlist($request) {
global $wpdb;
$user_id = $this->get_user_id_from_request($request);

if (!$user_id) {
return new WP_REST_Response(array('items' => array()), 200);
}

$currency = $this->currency_from_request($request);
$wishlist_id = $this->get_or_create_wishlist_id($user_id);
$items_table = $wpdb->prefix . 'yith_wcwl';

$rows = $wpdb->get_results($wpdb->prepare(
"SELECT prod_id FROM {$items_table} WHERE wishlist_id = %d ORDER BY dateadded DESC",
$wishlist_id
));

$items = array();
foreach ($rows as $row) {
$product = wc_get_product($row->prod_id);
if ($product) {
$items[] = array('product' => $this->product_payload($product, $currency));
}
}

return new WP_REST_Response(array('items' => $items), 200);
}

public function add_to_wishlist($request) {
global $wpdb;
$params = $request->get_json_params();
$product_id = isset($params['product_id']) ? intval($params['product_id']) : 0;

if (!$product_id || !wc_get_product($product_id)) {
return new WP_Error('invalid_product', 'Product not found.', array('status' => 400));
}

$user_id = $this->get_user_id_from_request($request);
if (!$user_id) {
return new WP_Error('unauthorized', 'Login required to use the wishlist.', array('status' => 401));
}

$wishlist_id = $this->get_or_create_wishlist_id($user_id);
$items_table = $wpdb->prefix . 'yith_wcwl';

$existing = $wpdb->get_var($wpdb->prepare(
"SELECT ID FROM {$items_table} WHERE wishlist_id = %d AND prod_id = %d LIMIT 1",
$wishlist_id, $product_id
));

if (!$existing) {
$wpdb->insert($items_table, array(
'prod_id' => $product_id,
'wishlist_id' => $wishlist_id,
'dateadded' => current_time('mysql'),
));
}

$this->invalidate_wishlist_cache($wishlist_id);
return $this->get_wishlist($request);
}

public function remove_from_wishlist($request) {
global $wpdb;
$params = $request->get_json_params();
$product_id = isset($params['product_id']) ? intval($params['product_id']) : 0;

$user_id = $this->get_user_id_from_request($request);
if (!$user_id) {
return new WP_Error('unauthorized', 'Login required to use the wishlist.', array('status' => 401));
}

$wishlist_id = $this->get_or_create_wishlist_id($user_id);
$items_table = $wpdb->prefix . 'yith_wcwl';

$wpdb->delete($items_table, array(
'wishlist_id' => $wishlist_id,
'prod_id' => $product_id,
));

$this->invalidate_wishlist_cache($wishlist_id);
return $this->get_wishlist($request);
}

// Writing straight to YITH's tables (rather than through YITH's own
// add()/remove() PHP methods, whose exact method names/signatures aren't
// something we can verify without their source) skips whatever cache
// invalidation those methods normally trigger. Confirmed symptom: the
// item is correctly in the DB right after the app writes it (see
// GET /debug/wishlist), but /favorites/ keeps showing the pre-add list
// until an action that goes through YITH's own code (e.g. removing an
// item on the website) happens to flush it. Flushing the object cache
// here — right after our own writes — closes that gap without needing
// to know YITH's internal cache keys.
private function invalidate_wishlist_cache($wishlist_id) {
wp_cache_flush();

if (function_exists('do_action')) {
do_action('litespeed_purge_all', 'alburagh wishlist updated');
}
}
}

class AlBuragh_API_Review_Controller {
public function get_reviews($request) {
$product_id = intval($request->get_param('product_id'));
if (!$product_id) {
return new WP_Error('missing_product', 'Product ID is required.', array('status' => 400));
}

$comments = get_comments(array(
'post_id' => $product_id,
'status' => 'approve',
'type' => 'review',
'number' => 20,
));

$reviews = array();
foreach ($comments as $comment) {
$rating = intval(get_comment_meta($comment->comment_ID, 'rating', true));
$reviews[] = array(
'id' => $comment->comment_ID,
'author' => $comment->comment_author,
'rating' => $rating,
'content' => $comment->comment_content,
'date' => $comment->comment_date
);
}
return new WP_REST_Response($reviews, 200);
}

public function add_review($request) {
$params = $request->get_json_params();
$product_id = isset($params['product_id']) ? intval($params['product_id']) : 0;
$rating = isset($params['rating']) ? intval($params['rating']) : 5;
$review = isset($params['review']) ? sanitize_textarea_field($params['review']) : '';

if (!$product_id || empty($review)) {
return new WP_Error('missing_fields', 'Product ID and review content are required.', array('status' => 400));
}

$user = wp_get_current_user();
$author_name = $user->exists() ? $user->display_name : (isset($params['author']) ? sanitize_text_field($params['author']) : 'Guest');
$author_email = $user->exists() ? $user->user_email : (isset($params['email']) ? sanitize_email($params['email']) : '');

$comment_data = array(
'comment_post_ID' => $product_id,
'comment_author' => $author_name,
'comment_author_email' => $author_email,
'comment_content' => $review,
'comment_type' => 'review',
'comment_approved' => 0, // Pending approval
);

$comment_id = wp_insert_comment($comment_data);
if ($comment_id) {
add_comment_meta($comment_id, 'rating', $rating);
return new WP_REST_Response(array('success' => true, 'message' => 'Review submitted for approval.'), 201);
}
return new WP_Error('review_failed', 'Failed to submit review.', array('status' => 500));
}
}

class AlBuragh_API_Coupon_Controller {
public function validate_coupon($request) {
$params = $request->get_json_params();
$coupon_code = isset($params['coupon_code']) ? sanitize_text_field($params['coupon_code']) : '';

if (empty($coupon_code)) {
return new WP_Error('missing_coupon', 'Coupon code is required.', array('status' => 400));
}

$coupon = new WC_Coupon($coupon_code);
if (!$coupon->get_id()) {
return new WP_Error('invalid_coupon', 'Coupon does not exist.', array('status' => 404));
}

$discounts = new WC_Discounts();
$valid = $discounts->is_coupon_valid($coupon);

if (is_wp_error($valid)) {
return new WP_Error('invalid_coupon', $valid->get_error_message(), array('status' => 400));
}

return new WP_REST_Response(array(
'valid' => true,
'code' => $coupon_code,
'type' => $coupon->get_discount_type(),
'amount' => floatval($coupon->get_amount())
), 200);
}
}

class AlBuragh_API_Address_Controller {
public function get_addresses($request) {
$auth_header = $request->get_header('Authorization');
if (empty($auth_header)) return new WP_Error('unauthorized', 'Token missing.', array('status' => 401));
$token = str_replace('Bearer ', '', $auth_header);
$user_id = AlBuragh_JWT_Auth::validate_token($token);

if (!$user_id) return new WP_Error('unauthorized', 'Session expired or token invalid.', array('status' => 401));

$addresses = get_user_meta($user_id, '_alburagh_addresses', true);
if (!is_array($addresses)) $addresses = array();

return new WP_REST_Response($addresses, 200);
}

public function save_address($request) {
$auth_header = $request->get_header('Authorization');
if (empty($auth_header)) return new WP_Error('unauthorized', 'Token missing.', array('status' => 401));
$token = str_replace('Bearer ', '', $auth_header);
$user_id = AlBuragh_JWT_Auth::validate_token($token);

if (!$user_id) return new WP_Error('unauthorized', 'Session expired or token invalid.', array('status' => 401));

$params = $request->get_json_params();
$address_id = isset($params['id']) ? intval($params['id']) : null;
$address_data = array(
'first_name' => isset($params['first_name']) ? sanitize_text_field($params['first_name']) : '',
'last_name' => isset($params['last_name']) ? sanitize_text_field($params['last_name']) : '',
'address_1' => isset($params['address_1']) ? sanitize_text_field($params['address_1']) : '',
'address_2' => isset($params['address_2']) ? sanitize_text_field($params['address_2']) : '',
'city' => isset($params['city']) ? sanitize_text_field($params['city']) : '',
'state' => isset($params['state']) ? sanitize_text_field($params['state']) : '',
'postcode' => isset($params['postcode']) ? sanitize_text_field($params['postcode']) : '',
'country' => isset($params['country']) ? sanitize_text_field($params['country']) : '',
'phone' => isset($params['phone']) ? sanitize_text_field($params['phone']) : '',
'type' => isset($params['type']) ? sanitize_text_field($params['type']) : 'home'
);

$addresses = get_user_meta($user_id, '_alburagh_addresses', true);
if (!is_array($addresses)) $addresses = array();

if ($address_id && isset($addresses[$address_id])) {
$addresses[$address_id] = $address_data;
} else {
$addresses[] = $address_data;
}

update_user_meta($user_id, '_alburagh_addresses', $addresses);
return new WP_REST_Response(array('success' => true, 'addresses' => $addresses), 200);
}
}

class AlBuragh_API_Order_Controller {
public function get_orders($request) {
$auth_header = $request->get_header('Authorization');
if (empty($auth_header)) return new WP_Error('unauthorized', 'Token missing.', array('status' => 401));
$token = str_replace('Bearer ', '', $auth_header);
$user_id = AlBuragh_JWT_Auth::validate_token($token);

if (!$user_id) return new WP_Error('unauthorized', 'Session expired or token invalid.', array('status' => 401));

$orders = wc_get_orders(array(
'customer_id' => $user_id,
'limit' => 20,
'orderby' => 'date',
'order' => 'DESC'
));

$order_data = array();
foreach ($orders as $order) {
$order_data[] = array(
'id' => $order->get_id(),
'status' => $order->get_status(),
'total' => floatval($order->get_total()),
'currency' => $order->get_currency(),
'date_created' => $order->get_date_created() ? $order->get_date_created()->date('Y-m-d H:i:s') : null,
'item_count' => $order->get_item_count()
);
}

return new WP_REST_Response($order_data, 200);
}

public function get_order_details($request) {
$auth_header = $request->get_header('Authorization');
if (empty($auth_header)) return new WP_Error('unauthorized', 'Token missing.', array('status' => 401));
$token = str_replace('Bearer ', '', $auth_header);
$user_id = AlBuragh_JWT_Auth::validate_token($token);

if (!$user_id) return new WP_Error('unauthorized', 'Session expired or token invalid.', array('status' => 401));

$order_id = intval($request->get_param('id'));
$order = wc_get_order($order_id);

if (!$order || $order->get_customer_id() != $user_id) {
return new WP_Error('not_found', 'Order not found or access denied.', array('status' => 404));
}

$items = array();
foreach ($order->get_items() as $item) {
$items[] = array(
'product_id' => $item->get_product_id(),
'name' => $item->get_name(),
'quantity' => $item->get_quantity(),
'total' => floatval($item->get_total())
);
}

return new WP_REST_Response(array(
'id' => $order->get_id(),
'status' => $order->get_status(),
'total' => floatval($order->get_total()),
'currency' => $order->get_currency(),
'date_created' => $order->get_date_created() ? $order->get_date_created()->date('Y-m-d H:i:s') : null,
'billing_address' => $order->get_address('billing'),
'shipping_address' => $order->get_address('shipping'),
'payment_method' => $order->get_payment_method_title(),
'items' => $items
), 200);
}
}

// Debug controller
class AlBuragh_API_Debug_Controller {
  private function get_user_id_from_request($request) {
    $auth_header = $request->get_header('Authorization');
    if (empty($auth_header)) return 0;
    $token = str_replace('Bearer ', '', $auth_header);
    $user_id = AlBuragh_JWT_Auth::validate_token($token);
    return $user_id ? intval($user_id) : 0;
  }

  public function debug_cart($request) {
    $user_id = $this->get_user_id_from_request($request);
    if (!$user_id) {
      return new WP_Error('unauthorized', 'Token invalid', array('status' => 401));
    }

    $result = array(
      'user_id' => $user_id,
      'blog_id' => get_current_blog_id(),
      'persistent_meta_key' => '_woocommerce_persistent_cart_' . get_current_blog_id(),
    );

    // Get all user meta
    $all_meta = get_user_meta($user_id);
    $result['all_user_meta_keys'] = array_keys($all_meta);

    // Get persistent cart specifically
    $persistent_key = '_woocommerce_persistent_cart_' . get_current_blog_id();
    $persistent = get_user_meta($user_id, $persistent_key, true);
    $result['persistent_cart_raw'] = $persistent;

    // Get mobile cart
    $mobile = get_user_meta($user_id, '_alburagh_mobile_cart', true);
    $result['mobile_cart_raw'] = $mobile;

    // Check WooCommerce session
    if (function_exists('WC')) {
      $session_data = get_user_meta($user_id, '_woocommerce_session', true);
      $result['woocommerce_session_raw'] = $session_data;
    }

    return new WP_REST_Response($result, 200);
  }

  // Diagnoses "app favorites don't show on the website" reports: the app
  // and the website must be reading/writing the exact same YITH wishlist
  // row for this user. If get_or_create_wishlist_id() ever fails to find
  // the website's existing default wishlist (e.g. a different is_default
  // convention than assumed), it silently creates a second, disconnected
  // one for the app — this dumps every wishlist row WordPress has for the
  // user so that split is visible instead of guessed at.
  public function debug_wishlist($request) {
    global $wpdb;
    $user_id = $this->get_user_id_from_request($request);
    if (!$user_id) {
      return new WP_Error('unauthorized', 'Token invalid', array('status' => 401));
    }

    $lists_table = $wpdb->prefix . 'yith_wcwl_lists';
    $items_table = $wpdb->prefix . 'yith_wcwl';

    $result = array(
      'user_id' => $user_id,
      'lists_table' => $lists_table,
      'items_table' => $items_table,
      'lists_table_exists' => (bool) $wpdb->get_var($wpdb->prepare('SHOW TABLES LIKE %s', $lists_table)),
      'items_table_exists' => (bool) $wpdb->get_var($wpdb->prepare('SHOW TABLES LIKE %s', $items_table)),
    );

    if ($result['lists_table_exists']) {
      $lists = $wpdb->get_results($wpdb->prepare(
        "SELECT * FROM {$lists_table} WHERE user_id = %d",
        $user_id
      ), ARRAY_A);
      $result['wishlists_for_user'] = $lists;

      if ($result['items_table_exists'] && $lists) {
        foreach ($lists as $list) {
          $items = $wpdb->get_results($wpdb->prepare(
            "SELECT * FROM {$items_table} WHERE wishlist_id = %d",
            $list['ID']
          ), ARRAY_A);
          $result['items_by_wishlist_id'][$list['ID']] = $items;
        }
      }
    }

    return new WP_REST_Response($result, 200);
  }

  // Verifies the assumptions alburagh_get_fixed_price()/
  // alburagh_format_price_for_currency() make about the VillaTheme "Multi
  // Currency for WooCommerce" plugin's per-product fixed pricing, since
  // that plugin's source isn't available to check ahead of time. Hits a
  // test USD amount through the same conversion path every price field
  // in the app uses, so a wrong guess about the plugin's classes/methods
  // shows up here instead of as a silently-wrong price in the app.
  public function debug_currency($request) {
    $test_amount = 10;

    $result = array(
      'test_usd_amount' => $test_amount,
      'woomulti_currency_class_exists' => class_exists('WOOMULTI_CURRENCY_F_Data'),
      'wmc_get_price_function_exists' => function_exists('wmc_get_price'),
    );

    if ($result['woomulti_currency_class_exists']) {
      $wmc = WOOMULTI_CURRENCY_F_Data::get_ins();
      $result['woomulti_currency_instance_class'] = is_object($wmc) ? get_class($wmc) : null;

      if (is_object($wmc)) {
        // Confirmed real methods (from a prior introspection dump), tried
        // defensively since we still don't have the plugin's source to
        // check exact signatures against.
        if (method_exists($wmc, 'get_current_currency')) {
          $result['current_currency'] = $wmc->get_current_currency();
        }
        if (method_exists($wmc, 'get_default_currency')) {
          $result['default_currency'] = $wmc->get_default_currency();
        }
        if (method_exists($wmc, 'get_list_currencies')) {
          $result['currency_list'] = $wmc->get_list_currencies();
        }
        if (method_exists($wmc, 'get_currencies')) {
          $result['currencies'] = $wmc->get_currencies();
        }
        if (method_exists($wmc, 'get_exchange')) {
          try {
            $result['get_exchange_IQD'] = $wmc->get_exchange('IQD');
          } catch (\Throwable $e) {
            $result['get_exchange_IQD_error'] = $e->getMessage();
          }
        }
      }
    }

    if (function_exists('wmc_get_exchange_rate')) {
      try {
        $result['wmc_get_exchange_rate_IQD'] = wmc_get_exchange_rate('IQD');
      } catch (\Throwable $e) {
        $result['wmc_get_exchange_rate_IQD_error'] = $e->getMessage();
      }
    }

    // Per-product fixed IQD prices (confirmed this is how this store prices
    // Iraq customers, not a global exchange rate) — pass ?product_id=34259
    // to inspect a real product's stored meta and find the actual key/
    // method VillaTheme uses, instead of guessing a meta key name blind.
    $product_id = intval($request->get_param('product_id'));
    if ($product_id) {
      $result['product_id'] = $product_id;
      $result['product_exists'] = (bool) wc_get_product($product_id);
      $result['product_all_meta_keys'] = array_keys(get_post_meta($product_id));
      $result['product_regular_price_usd'] = get_post_meta($product_id, '_regular_price', true);
      $result['regular_price_wmcp_raw'] = get_post_meta($product_id, '_regular_price_wmcp', true);
      $result['sale_price_wmcp_raw'] = get_post_meta($product_id, '_sale_price_wmcp', true);

      if (isset($wmc) && is_object($wmc) && method_exists($wmc, 'check_fixed_price')) {
        try {
          $result['check_fixed_price_IQD'] = $wmc->check_fixed_price($product_id, 'IQD');
        } catch (\Throwable $e) {
          $result['check_fixed_price_IQD_error'] = $e->getMessage();
        }
      }
    }

    $result['fixed_iqd_price_for_product'] = $product_id
      ? alburagh_get_fixed_price($product_id, '_regular_price_wmcp', 'IQD')
      : null;
    $result['full_price_info'] = alburagh_format_price_for_currency(
      $test_amount,
      'IQD',
      $product_id,
      '_regular_price_wmcp'
    );

    return new WP_REST_Response($result, 200);
  }
}

// 3. SECURE ENDPOINTS ROUTING SETUP
add_action('rest_api_init', function () {
$auth = new AlBuragh_API_Auth_Controller();
$prod = new AlBuragh_API_Product_Controller();
$autologin = new AlBuragh_API_AutoLogin_Controller();
$cart = new AlBuragh_API_Cart_Controller();
$wishlist = new AlBuragh_API_Wishlist_Controller();
$review = new AlBuragh_API_Review_Controller();
$coupon = new AlBuragh_API_Coupon_Controller();
$address = new AlBuragh_API_Address_Controller();
$order = new AlBuragh_API_Order_Controller();
$debug = new AlBuragh_API_Debug_Controller();

// Authenticators
register_rest_route('alburagh/v1', '/login', array(
'methods' => 'POST',
'callback' => array($auth, 'login'),
'permission_callback' => '__return_true'
));
register_rest_route('alburagh/v1', '/register', array(
'methods' => 'POST',
'callback' => array($auth, 'register'),
'permission_callback' => '__return_true'
));
register_rest_route('alburagh/v1', '/forgot-password', array(
'methods' => 'POST',
'callback' => array($auth, 'forgot_password'),
'permission_callback' => '__return_true'
));
register_rest_route('alburagh/v1', '/profile', array(
'methods' => 'GET',
'callback' => array($auth, 'get_profile'),
'permission_callback' => '__return_true'
));
register_rest_route('alburagh/v1', '/profile', array(
'methods' => 'PUT',
'callback' => array($auth, 'update_profile'),
'permission_callback' => '__return_true'
));

// Products
register_rest_route('alburagh/v1', '/products', array(
'methods' => 'GET',
'callback' => array($prod, 'get_products'),
'permission_callback' => '__return_true'
));
register_rest_route('alburagh/v1', '/featured-products', array(
'methods' => 'GET',
'callback' => array($prod, 'get_featured_products'),
'permission_callback' => '__return_true'
));
register_rest_route('alburagh/v1', '/new-arrivals', array(
'methods' => 'GET',
'callback' => array($prod, 'get_new_arrivals'),
'permission_callback' => '__return_true'
));
register_rest_route('alburagh/v1', '/sale-products', array(
'methods' => 'GET',
'callback' => array($prod, 'get_sale_products'),
'permission_callback' => '__return_true'
));
register_rest_route('alburagh/v1', '/search', array(
'methods' => 'GET',
'callback' => array($prod, 'search'),
'permission_callback' => '__return_true'
));
register_rest_route('alburagh/v1', '/categories', array(
'methods' => 'GET',
'callback' => array($prod, 'get_categories'),
'permission_callback' => '__return_true'
));

// Checkout happens on the website itself (COD/PayPal/card, whatever
// WooCommerce has configured); the app just gets the customer there already
// logged in.
register_rest_route('alburagh/v1', '/auto-login-link', array(
'methods' => 'POST',
'callback' => array($autologin, 'create_link'),
'permission_callback' => '__return_true'
));

// ==========================================
// NEW ENDPOINTS FOR MISSING APIS
// ==========================================

// Cart Utilities
register_rest_route('alburagh/v1', '/cart', array(
array(
'methods' => 'GET',
'callback' => array($cart, 'get_cart'),
'permission_callback' => '__return_true'
),
array(
'methods' => 'POST',
'callback' => array($cart, 'add_to_cart'),
'permission_callback' => '__return_true'
),
array(
'methods' => 'PUT',
'callback' => array($cart, 'update_cart'),
'permission_callback' => '__return_true'
),
array(
'methods' => 'DELETE',
'callback' => array($cart, 'clear_cart'),
'permission_callback' => '__return_true'
)
));

// Wishlist (backed by YITH WooCommerce Wishlist's own tables)
register_rest_route('alburagh/v1', '/wishlist', array(
array(
'methods' => 'GET',
'callback' => array($wishlist, 'get_wishlist'),
'permission_callback' => '__return_true'
),
array(
'methods' => 'POST',
'callback' => array($wishlist, 'add_to_wishlist'),
'permission_callback' => '__return_true'
),
array(
'methods' => 'DELETE',
'callback' => array($wishlist, 'remove_from_wishlist'),
'permission_callback' => '__return_true'
)
));

// Reviews
register_rest_route('alburagh/v1', '/reviews', array(
array(
'methods' => 'GET',
'callback' => array($review, 'get_reviews'),
'permission_callback' => '__return_true'
),
array(
'methods' => 'POST',
'callback' => array($review, 'add_review'),
'permission_callback' => '__return_true'
)
));

// Coupon Validators
register_rest_route('alburagh/v1', '/validate-coupon', array(
'methods' => 'POST',
'callback' => array($coupon, 'validate_coupon'),
'permission_callback' => '__return_true'
));

// Custom Address Adjustments
register_rest_route('alburagh/v1', '/addresses', array(
array(
'methods' => 'GET',
'callback' => array($address, 'get_addresses'),
'permission_callback' => '__return_true'
),
array(
'methods' => 'POST',
'callback' => array($address, 'save_address'),
'permission_callback' => '__return_true'
)
));

// Orders
register_rest_route('alburagh/v1', '/orders', array(
'methods' => 'GET',
'callback' => array($order, 'get_orders'),
'permission_callback' => '__return_true'
));

register_rest_route('alburagh/v1', '/orders/(?P<id>\d+)', array(
'methods' => 'GET',
'callback' => array($order, 'get_order_details'),
'permission_callback' => '__return_true'
));

// Debug endpoint
register_rest_route('alburagh/v1', '/debug/cart', array(
'methods' => 'GET',
'callback' => array($debug, 'debug_cart'),
'permission_callback' => '__return_true'
));

register_rest_route('alburagh/v1', '/debug/wishlist', array(
'methods' => 'GET',
'callback' => array($debug, 'debug_wishlist'),
'permission_callback' => '__return_true'
));

register_rest_route('alburagh/v1', '/debug/currency', array(
'methods' => 'GET',
'callback' => array($debug, 'debug_currency'),
'permission_callback' => '__return_true'
));
});
