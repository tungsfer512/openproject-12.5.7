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
#++require 'rspec'

require 'spec_helper'
require_relative './eager_loading_mock_wrapper'

describe API::V3::WorkPackages::EagerLoading::CustomValue do
  let!(:work_package) { create(:work_package) }
  let!(:type) { work_package.type }
  let!(:other_type) { create(:type) }
  let!(:project) { work_package.project }
  let!(:other_project) { create(:project) }
  let!(:user) { create(:user) }
  let!(:version) { create(:version, project:) }

  describe 'multiple CFs' do
    let!(:type_project_list_cf) do
      create(:list_wp_custom_field).tap do |cf|
        type.custom_fields << cf
        project.work_package_custom_fields << cf
      end
    end
    let!(:type_project_user_cf) do
      create(:user_wp_custom_field).tap do |cf|
        type.custom_fields << cf
        project.work_package_custom_fields << cf
      end
    end
    let!(:type_project_version_cf) do
      create(:version_wp_custom_field, name: 'blubs').tap do |cf|
        type.custom_fields << cf
        project.work_package_custom_fields << cf
      end
    end
    let!(:for_all_type_cf) do
      create(:list_wp_custom_field, is_for_all: true).tap do |cf|
        type.custom_fields << cf
      end
    end
    let!(:for_all_other_type_cf) do
      create(:list_wp_custom_field, is_for_all: true).tap do |cf|
        other_type.custom_fields << cf
      end
    end
    let!(:type_other_project_cf) do
      create(:list_wp_custom_field).tap do |cf|
        type.custom_fields << cf
        other_project.work_package_custom_fields << cf
      end
    end
    let!(:other_type_project_cf) do
      create(:list_wp_custom_field).tap do |cf|
        other_type.custom_fields << cf
        project.work_package_custom_fields << cf
      end
    end

    describe '.apply' do
      it 'preloads the custom fields and values' do
        create(:custom_value,
               custom_field: type_project_list_cf,
               customized: work_package,
               value: type_project_list_cf.custom_options.last.id)

        build(:custom_value,
              custom_field: type_project_user_cf,
              customized: work_package,
              value: user.id)
                  .save(validate: false)

        create(:custom_value,
               custom_field: type_project_version_cf,
               customized: work_package,
               value: version.id)

        work_package = WorkPackage.first
        wrapped = EagerLoadingMockWrapper.wrap(described_class, [work_package])

        expect(type)
          .not_to receive(:custom_fields)
        expect(project)
          .not_to receive(:all_work_package_custom_fields)

        [CustomOption, User, Version].each do |klass|
          expect(klass)
            .not_to receive(:find_by)
        end

        wrapped.each do |w|
          expect(w.available_custom_fields)
            .to match_array [type_project_list_cf,
                             type_project_version_cf,
                             type_project_user_cf,
                             for_all_type_cf]

          expect(work_package.send(type_project_version_cf.attribute_getter))
            .to eql version
          expect(work_package.send(type_project_list_cf.attribute_getter))
            .to eql type_project_list_cf.custom_options.last.name
          expect(work_package.send(type_project_user_cf.attribute_getter))
            .to eql user
        end
      end
    end
  end

  describe '#usages returning an is_for_all custom field within one project (Regression #28435)' do
    let!(:for_all_type_cf) do
      create(:list_wp_custom_field, is_for_all: true).tap do |cf|
        type.custom_fields << cf
      end
    end
    let(:other_project) { create(:project) }

    subject { described_class.new [work_package] }

    before do
      # Assume that one custom field has an entry in project_custom_fields
      for_all_type_cf.projects << other_project
    end

    it 'still allows looking up the global custom field in a different project' do
      # Exhibits the same behavior as in regression, usage returns a hash with project_id set for a global
      # custom field
      expect(for_all_type_cf.is_for_all).to be(true)
      expect(subject.send(:usages))
        .to include("project_id" => other_project.id, "type_id" => type.id, "custom_field_id" => for_all_type_cf.id)

      wrapped = EagerLoadingMockWrapper.wrap(described_class, [work_package])
      expect(wrapped.first.available_custom_fields).to include(for_all_type_cf)
    end
  end

  describe '#usages returning an is_for_all custom field within multiple projects (Regression #28452)' do
    let!(:for_all_type_cf) do
      create(:list_wp_custom_field, is_for_all: true).tap do |cf|
        type.custom_fields << cf
      end
    end
    let(:other_project) { create(:project) }
    let(:other_project2) { create(:project) }

    subject { described_class.new [work_package] }

    before do
      # Assume that one custom field has an entry in project_custom_fields
      for_all_type_cf.projects << other_project
      for_all_type_cf.projects << other_project2
    end

    it 'does not double add the custom field to the available CFs' do
      # Exhibits the same behavior as in regression, usage returns a hash with project_id set for a global
      # custom field
      expect(for_all_type_cf.is_for_all).to be(true)
      expect(subject.send(:usages))
        .to include("project_id" => other_project.id, "type_id" => type.id, "custom_field_id" => for_all_type_cf.id)

      expect(subject.send(:usages))
        .to include("project_id" => other_project2.id, "type_id" => type.id, "custom_field_id" => for_all_type_cf.id)

      wrapped = EagerLoadingMockWrapper.wrap(described_class, [work_package])
      expect(wrapped.first.available_custom_fields.length).to eq(1)
      expect(wrapped.first.available_custom_fields.to_a).to eq([for_all_type_cf])
    end
  end
end
