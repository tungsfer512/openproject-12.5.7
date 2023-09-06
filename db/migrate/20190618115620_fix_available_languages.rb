class FixAvailableLanguages < ActiveRecord::Migration[5.2]
  def up
    if Setting.where(name: 'available_languages').exists? # rubocop:disable Rails/WhereExists
      Setting.reset_column_information

      Setting.available_languages = Setting.available_languages.map do |lang|
        if lang == 'zh'
          'zh-CN'
        else
          lang
        end
      end
    end

    User.where(language: 'zh').update_all(language: 'zh-CN')
  end

  def down
    if Setting.where(name: 'available_languages').exists? # rubocop:disable Rails/WhereExists
      Setting.reset_column_information

      Setting.available_languages = Setting.available_languages.map do |lang|
        if lang == 'zh-CN'
          'zh'
        else
          lang
        end
      end
    end

    User.where(language: 'zh-CN').update_all(language: 'zh')
  end
end
