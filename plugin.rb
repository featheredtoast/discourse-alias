# frozen_string_literal: true

# name: discourse-alias
# about: Support for account aliasing
# version: 0.1
# authors: Jeff Wong
# transpile_js: true

after_initialize do

  add_to_class(:user, :find_max_alias_tl) do
    max_tl = 0
    TrustLevel.valid_range.to_a.each do |trust_level|
      if custom_fields["alias_tl#{trust_level}_count"].to_i > 0
        max_tl = trust_level
      end
    end
    max_tl
  end

  add_to_class(:user, :increment_alias_tl_count) do |trust_level|
    tl_count = custom_fields["alias_tl#{trust_level}_count"].to_i
    if tl_count > 0
      tl_count = tl_count + 1
    else
      tl_count = 1
    end
    custom_fields["alias_tl#{trust_level}_count"] = tl_count.to_s
    save_custom_fields
    tl_count
  end

  add_to_class(:user, :decrement_alias_tl_count) do |trust_level|
    tl_count = custom_fields["alias_tl#{trust_level}_count"].to_i
    tl_count = tl_count - 1
    if tl_count > 0
      custom_fields["alias_tl#{trust_level}_count"] = tl_count.to_s
    else
      custom_fields.delete("alias_tl#{trust_level}_count")
    end
    save_custom_fields
    tl_count
  end

  # Links a base user to an alias:
  # base_user.add_user_alias alias_user
  add_to_class(:user, :add_user_alias) do |user|
    record_id = self.id
    # If current user is also an alias, follow to the 'base' user
    if custom_fields.include? 'alias_for'
      record_id = custom_fields['alias_for']
    end
    user.custom_fields["alias_for"] = record_id
    user.save_custom_fields

    # update trust level if this user is a higher trust level
    if self.trust_level < user.trust_level
      base_promotion = Promotion.new(self)
      base_promotion.change_trust_level!(user.trust_level)
    end

    increment_alias_tl_count user.trust_level
  end

  # Remove linked base user for an alias user.
  # Unmarks a user as an alias to another user, removing the associations
  # alias_user.unmark_as_alias
  add_to_class(:user, :unmark_as_alias) do

    record = self.record_for_alias
    tl_count = record.decrement_alias_tl_count trust_level
    if tl_count <= 0
      base_demotion = Promotion.new(record)
      base_demotion.change_trust_level!(record.find_max_alias_tl)
    end

    custom_fields.delete "alias_for"
    save_custom_fields
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
    if custom_fields.include? 'alias_for'
      record_id = custom_fields['alias_for']
      return User.find_by(id: record_id)
    end
    self
  end

  # Checks if the current user record is an alias
  add_to_class(:user, :is_alias?) do
    if custom_fields.include? 'alias_for'
      return true
    end
    false
  end

  # Reading trust levels - read from base user record
  add_to_serializer(:user_card, :trust_level) do
    object.record_for_alias.trust_level
  end

  reloadable_patch do
    class ::User
      alias_method :has_trust_level_orig?, :has_trust_level?
      def has_trust_level?(level)
        self.record_for_alias.has_trust_level_orig? level
      end
    end

  end

  reloadable_patch do
    class ::Promotion
      alias_method :review_orig, :review
      alias_method :change_trust_level_orig!, :change_trust_level!

      def review
        if @user&.is_alias?
          # We grab the max trust level to review
          user = @user&.record_for_alias
          return false if user.blank? || !user.manual_locked_trust_level.nil?
          return false if user.trust_level >= TrustLevel[2]

          # if alias' trust level is higher than base, level up our base user
          if @user.trust_level > user.trust_level
            base_promotion = Promotion.new(user)
            base_promotion.change_trust_level!(@user.trust_level)
          end

          review_method = :"review_tl#{user.trust_level}"
          # And then review based on the current alias.
          return public_send(review_method) if respond_to?(review_method)
          false
        else
          review_orig
        end
      end

      def change_trust_level!(level, opts = {})
        # We also change trust level on the base user when an alias is changed
        # this keeps the alias changed on the "highest" trust changed to.

        if @user&.is_alias?
          old_level = @user.trust_level
          if change_trust_level_orig!(level, opts)
            new_level = @user.trust_level
            user = @user&.record_for_alias

            # keep track of trust levels, do not demote if there are still other aliases on the current tl
            tl_old_count = user.decrement_alias_tl_count old_level
            user.increment_alias_tl_count new_level

            # find next trust level for base user
            # Demotions: do not demote if we still have aliases on current
            if old_level > new_level && tl_old_count > 0
              return
            end

            base_promotion = Promotion.new(user)
            base_promotion.change_trust_level!(user.find_max_alias_tl, opts)
          end
        else
          change_trust_level_orig!(level, opts)
        end
      end
    end
  end

  # Calculating trust levels - needs to consider posts for all aliases as well?
  # Calculated in Promotion.review, called from topics controllers
  # Grab stats from all associated users? seems rather complicated.
  # How about: after review, check to see if trust level is higher after, and promote base user if so
  # TL3 will need to be checked or updated.
  # manual TL pinnings will also need to affect root user as well.
  # TL group promotions - affect only base user probably
end
