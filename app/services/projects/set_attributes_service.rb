#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2023 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

module Projects
  class SetAttributesService < ::BaseServices::SetAttributes
    private

    def set_attributes(params)
      attributes = params.dup
      status_attributes = attributes.delete(:status) || {}

      ret = super(attributes)

      update_status(status_attributes)

      ret
    end

    def set_default_attributes(attributes)
      attribute_keys = attributes.keys.map(&:to_s)

      set_default_public(attribute_keys.include?('public'))
      set_default_module_names(attribute_keys.include?('enabled_module_names'))
      set_default_types(attribute_keys.include?('types') || attribute_keys.include?('type_ids'))
      set_default_active_work_package_custom_fields(attribute_keys.include?('work_package_custom_fields'))
    end

    def set_default_public(provided)
      model.public = Setting.default_projects_public? unless provided
    end

    def set_default_module_names(provided)
      model.enabled_module_names = Setting.default_projects_modules if !provided && model.enabled_module_names.empty?
    end

    def set_default_types(provided)
      model.types = ::Type.default if !provided && model.types.empty?
    end

    def set_default_active_work_package_custom_fields(provided)
      return if provided

      model.work_package_custom_fields = WorkPackageCustomField
        .joins(:types)
        .where(types: { id: model.type_ids })
        .distinct
    end

    def update_status(attributes)
      with_hack_around_faulty_enum(attributes) do |safe_attributes|
        if model.status
          model.status.attributes = safe_attributes
        else
          model.build_status(safe_attributes)
        end
      end
    end

    # Hack around ArgumentError on faulty enum values
    # https://github.com/rails/rails/issues/13971
    def with_hack_around_faulty_enum(attributes)
      faulty_code = if faulty_code?(attributes)
                      attributes.delete(:code)
                    end

      yield(attributes)

      if faulty_code
        # set an arbitrary status code first to get rails internal into correct state
        model.status.code = first_not_set_code
        # hack into rails internals to set faulty code
        code_attributes = model.status.instance_variable_get(:@attributes)['code']
        code_attributes.instance_variable_set(:@value_before_type_cast, faulty_code)
        code_attributes.instance_variable_set(:@value, faulty_code)
      end
    end

    def faulty_code?(attributes)
      attributes && attributes[:code] && Projects::Status.codes.keys.exclude?(attributes[:code].to_s)
    end

    def first_not_set_code
      (Projects::Status.codes.keys - [model.status.code]).first
    end
  end
end
