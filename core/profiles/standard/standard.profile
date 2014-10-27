<?php
/**
 * @file
 * Enables modules and site configuration for a standard site installation.
 */

use Drupal\contact\Entity\ContactForm;
use Drupal\Core\Form\FormStateInterface;
use Drupal\comment\Plugin\Field\FieldType\CommentItemInterface;

/**
 * Implements hook_install_tasks().
 *
 * Sets up the install tasks for the Standard install profile.
 */
function standard_install_tasks() {
  $tasks = array(
    'standard_install_tasks_update_manager' => array(),
    'standard_install_tasks_comment' => array(),
    'standard_install_tasks_user' => array(),
    'standard_install_tasks_menu' => array(),
    'standard_install_tasks_shortcut' => array(),
  );

  return $tasks;
}

/**
 * Install task to configure the Update Manager module.
 */
function standard_install_tasks_update_manager() {
  // Now that all modules are installed, make sure the entity storage and other
  // handlers are up to date with the current entity and field definitions. For
  // example, Path module adds a base field to nodes and taxonomy terms after
  // those modules are already installed.
  \Drupal::service('entity.definition_update_manager')->applyUpdates();
}

/**
 * Install task to configure the Comment module.
 */
function standard_install_tasks_comment() {
  // Add comment field to article node type.
  \Drupal::service('comment.manager')->addDefaultField('node', 'article', 'comment', CommentItemInterface::OPEN);

  // Hide the comment field in the rss view mode.
  entity_get_display('node', 'article', 'rss')
    ->removeComponent('comment')
    ->save();
}

/**
 * Install task to configure the User module.
 */
function standard_install_tasks_user() {
  // Allow visitor account creation with administrative approval.
  $user_settings = \Drupal::config('user.settings');
  $user_settings->set('register', USER_REGISTER_VISITORS_ADMINISTRATIVE_APPROVAL)->save();

  // Enable default permissions for system roles.
  user_role_grant_permissions(DRUPAL_ANONYMOUS_RID, array('access comments'));
  user_role_grant_permissions(DRUPAL_AUTHENTICATED_RID, array('access comments', 'post comments', 'skip comment approval'));

  // Enable all permissions for the administrator role.
  user_role_grant_permissions('administrator', array_keys(\Drupal::service('user.permissions')->getPermissions()));
  // Set this as the administrator role.
  $user_settings->set('admin_role', 'administrator')->save();

  // Assign user 1 the "administrator" role.
  db_insert('users_roles')
    ->fields(array('uid' => 1, 'rid' => 'administrator'))
    ->execute();

  user_role_grant_permissions(DRUPAL_ANONYMOUS_RID, array('access site-wide contact form'));
  user_role_grant_permissions(DRUPAL_AUTHENTICATED_RID, array('access site-wide contact form'));

  // Allow authenticated users to use shortcuts.
  user_role_grant_permissions(DRUPAL_AUTHENTICATED_RID, array('access shortcuts'));
}

/**
 * Install task to configure the Menu module.
 */
function standard_install_tasks_menu() {
  // Enable the Contact link in the footer menu.
  /** @var \Drupal\Core\Menu\MenuLinkManagerInterface $menu_link_manager */
  $menu_link_manager = \Drupal::service('plugin.manager.menu.link');
  $menu_link_manager->updateDefinition('contact.site_page', array('enabled' => 1));
}

/**
 * Install task to configure the Shortcut module.
 */
function standard_install_tasks_shortcut() {
  // Populate the default shortcut set.
  $shortcut = entity_create('shortcut', array(
    'shortcut_set' => 'default',
    'title' => t('Add content'),
    'weight' => -20,
    'path' => 'node/add',
  ));
  $shortcut->save();

  $shortcut = entity_create('shortcut', array(
    'shortcut_set' => 'default',
    'title' => t('All content'),
    'weight' => -19,
    'path' => 'admin/content',
  ));
  $shortcut->save();
}

/**
 * Implements hook_form_FORM_ID_alter() for install_configure_form().
 *
 * Allows the profile to alter the site configuration form.
 */
function standard_form_install_configure_form_alter(&$form, FormStateInterface $form_state) {
  // Pre-populate the site name with the server name.
  $form['site_information']['site_name']['#default_value'] = \Drupal::request()->server->get('SERVER_NAME');
  $form['#submit'][] = 'standard_form_install_configure_submit';
}

/**
 * Submission handler to sync the contact.form.feedback recipient.
 */
function standard_form_install_configure_submit($form, FormStateInterface $form_state) {
  $site_mail = $form_state->getValue('site_mail');
  ContactForm::load('feedback')->setRecipients([$site_mail])->save();
}
