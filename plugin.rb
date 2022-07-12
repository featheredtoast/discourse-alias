# frozen_string_literal: true

# name: discourse-alias
# about: Support for account aliasing
# version: 0.1
# authors: Jeff Wong
# transpile_js: true

after_initialize do

  # Add link methods for user
  add_to_class(:user, :add_user_alias) do |user|
    user.custom_fields["alias_for"] = self.id
    user.save_custom_fields
  end

  # remove link methods for user
  add_to_class(:user, :remove_user_alias) do |user|
    user.custom_fields.delete "alias_for"
    user.save_custom_fields
  end

  # Finds all aliases for this user
  add_to_class(:user, :aliases) do
    record_id = self.id
    if custom_fields.include? 'alias_for'
      record_id = custom_fields['alias_for']
    end
    User.joins(:user_custom_fields).where(user_custom_fields: { name: "alias_for", value: record_id }).uniq
  end

  # Finds the underlying record for the current user
  add_to_class(:user, :record_for_alias) do
    record_id = self.id
    if custom_fields.include? 'alias_for'
      record_id = custom_fields['alias_for']
    end
    User.find_by(id: record_id)
  end
end
