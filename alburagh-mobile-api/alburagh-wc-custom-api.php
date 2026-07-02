<?php
/**
* Plugin Name: AlBuragh WooCommerce Custom REST API
* Description: Fully production-ready custom REST API endpoint wrapper for AlBuragh online store.
* Exposes secure JWT authentication, products catalogs, custom address adjustments, cart utilities,
* reviews, coupon validators, and checkout engines.
* Version: 1.1.0
* Author: AlBuragh Developer Core
* Namespace: /wp-json/alburagh/v1/
*/
if ( ! defined( 'ABSPATH' ) ) {
exit; // Prevent direct access
}

// Ensure JWT Library or helper helper classes are configured
class AlBuragh_JWT_Auth {
private static $secret_key = '3yT!9Kq#Lz7@aP1$Vn8XmR2&wQ5HsE0';

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
$signature = hash_hmac('sha256', $base64UrlHeader . "." . $base64UrlPayload, self::$secret_key, true);
$base64UrlSignature = self::base64UrlEncode($signature);

return $base64UrlHeader . "." . $base64UrlPayload . "." . $base64UrlSignature;
}

public static function validate_token($token) {
$parts = explode('.', $token);
if (count($parts) !== 3) {
return false;
}

list($header, $payload, $signature) = $parts;
$sig_check = hash_hmac('sha256', $header . "." . $payload, self::$secret_key, true);

if (self::base64UrlEncode($sig_check) !== $signature) {
return false;
}

$decoded_payload = json_decode(base64_decode($payload), true);
if (isset($decoded_payload['exp']) && $decoded_payload['exp'] < time()) {
return false; // Expired
}

return $decoded_payload['data']['user']['id'];
}

private static function base64UrlEncode($text) {
return str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($text));
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
// Send recovery reset email code
retrieve_password($user->user_login);

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
return new WP_REST_Response(array(
'id' => $user->ID,
'username' => $user->user_login,
'email' => $user->user_email,
'first_name' => get_user_meta($user->ID, 'first_name', true),
'last_name' => get_user_meta($user->ID, 'last_name', true)
), 200);
}
}

class AlBuragh_API_Product_Controller {
public function get_products($request) {
if (!class_exists('WooCommerce')) {
return new WP_Error('wc_missing', 'WooCommerce is not active.', array('status' => 500));
}

$page = $request->get_param('page') ? intval($request->get_param('page')) : 1;
$per_page = $request->get_param('per_page') ? intval($request->get_param('per_page')) : 10;
$category = $request->get_param('category') ? intval($request->get_param('category')) : null;

$args = array(
'post_type'      => 'product',
'posts_per_page' => $per_page,
'paged'          => $page,
'post_status'    => 'publish'
);

if ($category) {
$args['tax_query'] = array(
array(
'taxonomy' => 'product_cat',
'field'    => 'term_id',
'terms'    => $category,
),
);
}

$query = new WP_Query($args);
$products = array();

foreach ($query->posts as $post) {
$product = wc_get_product($post->ID);
$products[] = $this->format_product($product);
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

foreach ($query->posts as $post) {
$product = wc_get_product($post->ID);
$products[] = $this->format_product($product);
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

foreach ($query->posts as $post) {
$product = wc_get_product($post->ID);
$products[] = $this->format_product($product);
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

foreach ($query->posts as $post) {
$product = wc_get_product($post->ID);
$products[] = $this->format_product($product);
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

foreach ($query->posts as $post) {
$product = wc_get_product($post->ID);
$products[] = $this->format_product($product);
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

private function format_product($product) {
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

return array(
'id' => $product->get_id(),
'name' => $product->get_name(),
'sku' => $product->get_sku(),
'description' => $product->get_description(),
'short_description' => $product->get_short_description(),
'price' => floatval($product->get_price()),
'regular_price' => floatval($product->get_regular_price()),
'sale_price' => $product->get_sale_price() ? floatval($product->get_sale_price()) : null,
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

class AlBuragh_API_Checkout_Controller {
public function checkout($request) {
if (!class_exists('WooCommerce')) {
return new WP_Error('wc_missing', 'WooCommerce is not active.', array('status' => 500));
}

$params = $request->get_json_params();
$billing = isset($params['billing_address']) ? $params['billing_address'] : array();
$shipping = isset($params['shipping_address']) ? $params['shipping_address'] : array();
$cart_items = isset($params['cart_items']) ? $params['cart_items'] : array();

if (empty($cart_items)) {
return new WP_Error('empty_cart', 'Cart items are required.', array('status' => 400));
}

// Initialize order
$order = wc_create_order();

foreach ($cart_items as $item) {
$product_id = intval($item['product_id']);
$quantity = intval($item['quantity']);
// Fixed deprecated get_product() to wc_get_product()
$order->add_product(wc_get_product($product_id), $quantity); 
}

// Set Addresses
$order->set_address($billing, 'billing');
$order->set_address($shipping, 'shipping');

// Set Payment Method
$payment_method = sanitize_text_field($params['payment_method']);
$payment_title = sanitize_text_field($params['payment_method_title']);

$order->set_payment_method($payment_method);
$order->set_payment_method_title($payment_title);
$order->calculate_totals();
$order->update_status('processing', 'Injected securely from AlBuragh App client.');

return new WP_REST_Response(array(
'id' => $order->get_id(),
'order_key' => $order->get_order_key(),
'status' => $order->get_status(),
'currency' => $order->get_currency(),
'total' => floatval($order->get_total()),
'date_created' => $order->get_date_created()->date('Y-m-d H:i:s'),
'billing_address' => $billing,
'shipping_address' => $shipping,
'payment_method' => $payment_method,
'payment_method_title' => $payment_title,
'line_items' => array()
), 201);
}
}

// ==========================================
// NEW CONTROLLERS FOR MISSING APIS
// ==========================================

class AlBuragh_API_Cart_Controller {
private function init_wc_cart() {
if (function_exists('WC')) {
if (WC()->session === null) {
WC()->init_session();
}
if (WC()->cart === null) {
WC()->cart = new WC_Cart();
}
}
}

public function get_cart($request) {
$this->init_wc_cart();
if (!WC()->cart) return new WP_Error('cart_error', 'Cart not initialized.', array('status' => 500));

$cart_items = array();
foreach (WC()->cart->get_cart() as $cart_item_key => $cart_item) {
$product = $cart_item['data'];
$cart_items[] = array(
'key' => $cart_item_key,
'product_id' => $product->get_id(),
'name' => $product->get_name(),
'quantity' => $cart_item['quantity'],
'price' => floatval($product->get_price()),
'total' => floatval($cart_item['line_total']),
'image' => wp_get_attachment_url($product->get_image_id())
);
}

return new WP_REST_Response(array(
'items' => $cart_items,
'total' => floatval(WC()->cart->get_total('edit')),
'subtotal' => floatval(WC()->cart->get_subtotal())
), 200);
}

public function add_to_cart($request) {
$this->init_wc_cart();
$params = $request->get_json_params();
$product_id = isset($params['product_id']) ? intval($params['product_id']) : 0;
$quantity = isset($params['quantity']) ? intval($params['quantity']) : 1;

if (!$product_id) {
return new WP_Error('missing_product', 'Product ID is required.', array('status' => 400));
}

$added = WC()->cart->add_to_cart($product_id, $quantity);
if ($added) {
return new WP_REST_Response(array('success' => true, 'message' => 'Product added to cart.'), 200);
}
return new WP_Error('add_failed', 'Could not add product to cart.', array('status' => 400));
}

public function update_cart($request) {
$this->init_wc_cart();
$params = $request->get_json_params();
$cart_item_key = isset($params['cart_item_key']) ? sanitize_text_field($params['cart_item_key']) : '';
$quantity = isset($params['quantity']) ? intval($params['quantity']) : 0;

if (empty($cart_item_key)) {
return new WP_Error('missing_key', 'Cart item key is required.', array('status' => 400));
}

if ($quantity > 0) {
WC()->cart->set_quantity($cart_item_key, $quantity);
return new WP_REST_Response(array('success' => true, 'message' => 'Cart updated.'), 200);
} else {
WC()->cart->remove_cart_item($cart_item_key);
return new WP_REST_Response(array('success' => true, 'message' => 'Item removed from cart.'), 200);
}
}

public function clear_cart($request) {
$this->init_wc_cart();
WC()->cart->empty_cart();
return new WP_REST_Response(array('success' => true, 'message' => 'Cart cleared.'), 200);
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

// 3. SECURE ENDPOINTS ROUTING SETUP
add_action('rest_api_init', function () {
$auth = new AlBuragh_API_Auth_Controller();
$prod = new AlBuragh_API_Product_Controller();
$chk = new AlBuragh_API_Checkout_Controller();
$cart = new AlBuragh_API_Cart_Controller();
$review = new AlBuragh_API_Review_Controller();
$coupon = new AlBuragh_API_Coupon_Controller();
$address = new AlBuragh_API_Address_Controller();
$order = new AlBuragh_API_Order_Controller();

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
'methods' => array('GET', 'PUT'),
'callback' => array($auth, 'get_profile'),
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

// Checkout
register_rest_route('alburagh/v1', '/checkout', array(
'methods' => 'POST',
'callback' => array($chk, 'checkout'),
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
});