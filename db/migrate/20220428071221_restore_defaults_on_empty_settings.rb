class RestoreDefaultsOnEmptySettings < ActiveRecord::Migration[6.1]
  def up
    settings = Setting.where(value: '')

    settings.find_each do |setting|
      definition = Settings::Definition[setting.name]

      if definition.nil?
        warn "Did not find definition for #{setting.name}. This setting is probably outdated an can be removed."
        next
      end

      next if definition.value == ''

      if definition.writable?
        setting.update_attribute(:value, definition.value)
      else
        setting.destroy
      end
    end
  end

  def down
    # Nothing to do
  end
end
