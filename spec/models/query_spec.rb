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

require 'spec_helper'

describe Query do
  let(:query) { build(:query) }
  let(:project) { create(:project) }
  let(:relation_columns_allowed) { true }
  let(:conditional_highlighting_allowed) { true }

  before do
    allow(EnterpriseToken)
      .to receive(:allows_to?)
      .with(:work_package_query_relation_columns)
      .and_return(relation_columns_allowed)

    allow(EnterpriseToken)
      .to receive(:allows_to?)
      .with(:conditional_highlighting)
      .and_return(conditional_highlighting_allowed)
  end

  describe '.new_default' do
    it 'set the default sortation' do
      query = described_class.new_default

      expect(query.sort_criteria)
        .to match_array([['id', 'asc']])
    end

    it 'does not use the default sortation if an order is provided' do
      query = described_class.new_default(sort_criteria: [['id', 'asc']])

      expect(query.sort_criteria)
        .to match_array([['id', 'asc']])
    end

    context 'with global subprojects include', with_settings: { display_subprojects_work_packages: true } do
      it 'sets the include subprojects' do
        expect(query.include_subprojects).to be true
      end
    end

    context 'with global subprojects include', with_settings: { display_subprojects_work_packages: false } do
      it 'sets the include subprojects' do
        expect(query.include_subprojects).to be false
      end
    end
  end

  describe 'include_subprojects' do
    let(:query) { described_class.new name: 'foo' }

    it 'is required' do
      expect(query).not_to be_valid

      expect(query.errors[:include_subprojects]).to include 'is not set to one of the allowed values.'
    end
  end

  describe 'hidden' do
    context 'with a view' do
      before do
        create(:view_work_packages_table, query:)
      end

      it 'is false' do
        expect(query.hidden).to be(false)
      end
    end

    context 'without a view' do
      it 'is true' do
        expect(query.hidden).to be(true)
      end
    end
  end

  describe 'timeline' do
    it 'has a property for timeline visible' do
      expect(query.timeline_visible).to be_falsey
      query.timeline_visible = true
      expect(query.timeline_visible).to be_truthy
    end

    it 'validates the timeline labels hash keys' do
      expect(query.timeline_labels).to eq({})
      expect(query).to be_valid

      query.timeline_labels = { 'left' => 'foobar', 'xyz' => 'bar' }
      expect(query).not_to be_valid

      query.timeline_labels = { 'left' => 'foobar', 'right' => 'bar', 'farRight' => 'blub' }
      expect(query).to be_valid
    end
  end

  describe 'highlighting' do
    context 'with EE' do
      it '#highlighted_attributes accepts valid values' do
        query.highlighted_attributes = %w(status priority due_date)
        expect(query).to be_valid
      end

      it '#highlighted_attributes rejects invalid values' do
        query.highlighted_attributes = %w(status bogus)
        expect(query).not_to be_valid
      end

      it '#hightlighting_mode accepts non-present values' do
        query.highlighting_mode = nil
        expect(query).to be_valid

        query.highlighting_mode = ''
        expect(query).to be_valid
      end

      it '#hightlighting_mode rejects invalid values' do
        query.highlighting_mode = 'bogus'
        expect(query).not_to be_valid
      end

      it '#available_highlighting_columns returns highlightable columns' do
        available_columns = {
          highlightable1: {
            highlightable: true
          },
          highlightable2: {
            highlightable: true
          },
          no_highlight: {}
        }

        allow(Queries::WorkPackages::Columns::PropertyColumn).to receive(:property_columns)
                                                                   .and_return(available_columns)

        expect(query.available_highlighting_columns.map(&:name)).to eq(%i{highlightable1 highlightable2})
      end

      describe '#highlighted_columns returns a valid subset of Columns' do
        let(:highlighted_attributes) { %i{status priority due_date foo} }

        before do
          query.highlighted_attributes = highlighted_attributes
        end

        it 'removes the offending values' do
          query.valid_subset!

          expect(query.highlighted_columns.map(&:name))
            .to match_array %i{status priority due_date}
        end
      end
    end

    context 'without EE' do
      let(:conditional_highlighting_allowed) { false }

      it 'always returns :none as highlighting_mode' do
        query.highlighting_mode = 'status'
        expect(query.highlighting_mode).to eq(:none)
      end

      it 'always returns nil as highlighted_attributes' do
        query.highlighting_mode = 'inline'
        query.highlighted_attributes = ['status']
        expect(query.highlighted_attributes).to be_empty
      end
    end
  end

  describe 'hierarchies' do
    it 'is enabled in default queries' do
      query = described_class.new_default
      expect(query.show_hierarchies).to be_truthy
      query.show_hierarchies = false
      expect(query.show_hierarchies).to be_falsey
    end

    it 'is mutually exclusive with group_by' do
      query = described_class.new_default
      expect(query.show_hierarchies).to be_truthy
      query.group_by = :assignee

      expect(query.save).to be_falsey
      expect(query).not_to be_valid
      expect(query.errors[:show_hierarchies].first)
        .to include(I18n.t('activerecord.errors.models.query.group_by_hierarchies_exclusive', group_by: 'assignee'))
    end
  end

  describe '#available_columns' do
    context 'with work_package_done_ratio NOT disabled' do
      it 'includes the done_ratio column' do
        expect(query.displayable_columns.map(&:name)).to include :done_ratio
      end
    end

    context 'with work_package_done_ratio disabled' do
      before do
        allow(WorkPackage).to receive(:done_ratio_disabled?).and_return(true)
      end

      it 'does not include the done_ratio column' do
        expect(query.displayable_columns.map(&:name)).not_to include :done_ratio
      end
    end

    context 'results caching' do
      let(:project2) { create(:project) }

      it 'does not call the db twice' do
        query.project = project

        query.displayable_columns

        expect(project)
          .not_to receive(:all_work_package_custom_fields)

        expect(project)
          .not_to receive(:types)

        query.displayable_columns
      end

      it 'does call the db if the project changes' do
        query.project = project

        query.displayable_columns

        query.project = project2

        expect(project2)
          .to receive(:all_work_package_custom_fields)
          .and_return []

        expect(project2)
          .to receive(:types)
          .and_return []

        query.displayable_columns
      end

      it 'does call the db if the project changes to nil' do
        query.project = project

        query.displayable_columns

        query.project = nil

        expect(WorkPackageCustomField)
          .to receive(:all)
          .and_return []

        expect(Type)
          .to receive(:all)
          .and_return []

        query.displayable_columns
      end
    end

    context 'relation_to_type columns' do
      let(:type_in_project) do
        type = create(:type)
        project.types << type

        type
      end

      let(:type_not_in_project) do
        create(:type)
      end

      before do
        type_in_project
        type_not_in_project
      end

      context 'when in project' do
        before do
          query.project = project
        end

        it 'includes the relation columns for project types' do
          expect(query.displayable_columns.map(&:name)).to include :"relations_to_type_#{type_in_project.id}"
        end

        it 'does not include the relation columns for types not in project' do
          expect(query.displayable_columns.map(&:name)).not_to include :"relations_to_type_#{type_not_in_project.id}"
        end

        context 'with the enterprise token disallowing relation columns' do
          let(:relation_columns_allowed) { false }

          it 'excludes the relation columns' do
            expect(query.displayable_columns.map(&:name)).not_to include :"relations_to_type_#{type_in_project.id}"
          end
        end
      end

      context 'when global' do
        before do
          query.project = nil
        end

        it 'includes the relation columns for all types' do
          expect(query.displayable_columns.map(&:name)).to include(:"relations_to_type_#{type_in_project.id}",
                                                                   :"relations_to_type_#{type_not_in_project.id}")
        end

        context 'with the enterprise token disallowing relation columns' do
          let(:relation_columns_allowed) { false }

          it 'excludes the relation columns' do
            expect(query.displayable_columns.map(&:name)).not_to include(:"relations_to_type_#{type_in_project.id}",
                                                                         :"relations_to_type_#{type_not_in_project.id}")
          end
        end
      end
    end

    context 'with relation_of_type columns' do
      before do
        stub_const('Relation::TYPES',
                   relation1: { name: :label_relates_to, sym_name: :label_relates_to, order: 1, sym: :relation1 },
                   relation2: { name: :label_duplicates, sym_name: :label_duplicated_by, order: 2, sym: :relation2 })
      end

      it 'includes the relation columns for every relation type' do
        expect(query.displayable_columns.map(&:name)).to include(:relations_of_type_relation1,
                                                                 :relations_of_type_relation2)
      end

      context 'with the enterprise token disallowing relation columns' do
        let(:relation_columns_allowed) { false }

        it 'excludes the relation columns' do
          expect(query.displayable_columns.map(&:name)).not_to include(:relations_of_type_relation1,
                                                                       :relations_of_type_relation2)
        end
      end
    end
  end

  describe '.displayable_columns' do
    it 'includes the id column' do
      expect(query.displayable_columns.detect { |c| c.name == :id })
        .not_to be_nil
    end

    it 'excludes the manual sorting column' do
      expect(query.displayable_columns.detect { |c| c.name == :manual_sorting })
        .to be_nil
    end

    it 'excludes the typeahead column' do
      expect(query.displayable_columns.detect { |c| c.name == :typeahead })
        .to be_nil
    end
  end

  describe '.available_columns' do
    let(:custom_field) { create(:list_wp_custom_field) }
    let(:type) { create(:type) }

    before do
      stub_const('Relation::TYPES',
                 relation1: { name: :label_relates_to, sym_name: :label_relates_to, order: 1, sym: :relation1 },
                 relation2: { name: :label_duplicates, sym_name: :label_duplicated_by, order: 2, sym: :relation2 })
    end

    context 'with the enterprise token allowing relation columns' do
      it 'has all static columns, cf columns and relation columns' do
        expected_columns = %i(id project assigned_to author
                              category created_at due_date estimated_hours
                              parent done_ratio priority responsible
                              spent_hours start_date status subject type
                              updated_at version) +
                           [custom_field.column_name.to_sym] +
                           [:"relations_to_type_#{type.id}"] +
                           %i(relations_of_type_relation1 relations_of_type_relation2)

        expect(described_class.available_columns.map(&:name)).to include *expected_columns
      end
    end

    context 'with the enterprise token disallowing relation columns' do
      let(:relation_columns_allowed) { false }

      it 'has all static columns, cf columns but no relation columns' do
        expected_columns = %i(id project assigned_to author
                              category created_at due_date estimated_hours
                              parent done_ratio priority responsible
                              spent_hours start_date status subject type
                              updated_at version) +
                           [custom_field.column_name.to_sym]

        unexpected_columns = [:"relations_to_type_#{type.id}"] +
                             %i(relations_of_type_relation1 relations_of_type_relation2)

        expect(described_class.available_columns.map(&:name)).to include *expected_columns
        expect(described_class.available_columns.map(&:name)).not_to include *unexpected_columns
      end
    end
  end

  describe '#valid?' do
    it 'is not valid without a name' do
      query.name = ''
      expect(query.save).to be_falsey
      expect(query.errors[:name].first).to include(I18n.t('activerecord.errors.messages.blank'))
    end

    context 'with a missing value and an operator that requires values' do
      before do
        query.add_filter('due_date', 't-', [''])
      end

      it 'is not valid and creates an error' do
        expect(query.valid?).to be_falsey
        expect(query.errors[:base].first).to include(I18n.t('activerecord.errors.messages.blank'))
      end
    end

    context 'when filters are blank' do
      let(:status) { create(:status) }
      let(:query) { build(:query).tap { |q| q.filters = [] } }

      it 'is valid' do
        expect(query)
          .to be_valid
      end
    end

    context 'with a missing value for a custom field' do
      let(:custom_field) do
        create(:text_issue_custom_field, is_filter: true, is_for_all: true)
      end

      before do
        query.add_filter(custom_field.column_name, '=', [''])
      end

      it 'has the name of the custom field in the error message' do
        expect(query).not_to be_valid
        expect(query.errors.messages[:base].to_s).to include(custom_field.name)
      end
    end

    context 'with a filter for a non existing custom field' do
      before do
        query.add_filter('cf_0', '=', ['1'])
      end

      it 'is not valid' do
        expect(query.valid?).to be_falsey
      end
    end
  end

  describe '#valid_subset!' do
    let(:valid_status) { build_stubbed(:status) }

    context 'filters' do
      before do
        allow(Status)
          .to receive(:all)
          .and_return([valid_status])

        allow(Status)
          .to receive(:exists?)
          .and_return(true)

        query.filters.clear
        query.add_filter('status_id', '=', values)

        query.valid_subset!
      end

      context 'for a status filter having valid and invalid values' do
        let(:values) { [valid_status.id.to_s, '99999'] }

        it 'leaves the filter' do
          expect(query.filters.length).to eq 1
        end

        it 'leaves only the valid value' do
          expect(query.filters[0].values)
            .to match_array [valid_status.id.to_s]
        end
      end

      context 'for a status filter having only invalid values' do
        let(:values) { ['99999'] }

        it 'removes the filter' do
          expect(query.filters.length).to eq 0
        end
      end

      context 'for an unavailable filter' do
        let(:values) { [valid_status.id.to_s] }

        before do
          query.add_filter('cf_0815', '=', ['1'])

          query.valid_subset!
        end

        it 'removes the invalid filter' do
          expect(query.filters.length).to eq 1
          expect(query.filters[0].name).to eq :status_id
        end
      end
    end

    context 'group_by' do
      before do
        query.group_by = group_by
      end

      context 'valid' do
        let(:group_by) { 'project' }

        it 'leaves the value untouched' do
          query.valid_subset!

          expect(query.group_by).to eql group_by
        end
      end

      context 'invalid' do
        let(:group_by) { 'cf_0815' }

        it 'removes the group by' do
          query.valid_subset!

          expect(query.group_by).to be_nil
        end
      end
    end

    context 'sort_criteria' do
      before do
        query.sort_criteria = sort_by
      end

      context 'valid' do
        let(:sort_by) { [['project', 'desc']] }

        it 'leaves the value untouched' do
          query.valid_subset!

          expect(query.sort_criteria).to eql sort_by
        end
      end

      context 'invalid' do
        let(:sort_by) { [['cf_0815', 'desc']] }

        it 'removes the sorting' do
          query.valid_subset!

          expect(query.sort_criteria).to be_empty
        end
      end

      context 'parent' do
        let(:sort_by) { [['parent', 'asc'], ['start_date', 'asc']] }

        it 'is valid' do
          expect(query).to be_valid
          expect(query.sort_criteria).to match_array [['id', 'asc'], ['start_date', 'asc']]
        end
      end

      context 'partially invalid' do
        let(:sort_by) { [['cf_0815', 'desc'], ['project', 'desc']] }

        it 'removes the offending values from sort' do
          query.valid_subset!

          expect(query.sort_criteria).to match_array [['project', 'desc']]
        end
      end
    end

    context 'columns' do
      before do
        query.column_names = columns
      end

      context 'valid' do
        let(:columns) { %i(status project) }

        it 'leaves the values untouched' do
          query.valid_subset!

          expect(query.column_names)
            .to match_array columns
        end
      end

      context 'invalid' do
        let(:columns) { %i(bogus cf_0815) }

        it 'removes the values' do
          query.valid_subset!

          expect(query.column_names)
            .to be_empty
        end
      end

      context 'partially invalid' do
        let(:columns) { %i(status cf_0815) }

        it 'removes the offending values' do
          query.valid_subset!

          expect(query.column_names)
            .to match_array [:status]
        end
      end
    end

    context 'highlighted_attributes' do
      let(:highlighted_attributes) { %i{status priority due_date foo} }

      before do
        query.highlighted_attributes = highlighted_attributes
      end

      it 'removes the offending values' do
        query.valid_subset!

        expect(query.highlighted_attributes)
          .to match_array %i{status priority due_date}
      end
    end
  end

  describe '#filter_for' do
    context 'for a status_id filter' do
      subject { query.filter_for('status_id') }

      it 'exists' do
        expect(subject).not_to be_nil
      end

      it 'has the context set' do
        expect(subject.context).to eql query
      end

      it 'reuses an existing filter' do
        expect(subject.object_id).to eql query.filter_for('status_id').object_id
      end
    end
  end

  describe 'filters after deserialization' do
    it 'sets the context (project) on deserialization' do
      query.save!

      query.reload
      query.filters.each do |filter|
        expect(filter.context).to eql(query)
      end
    end
  end

  describe 'filters and statement_filters (private method)' do
    def subproject_filter?(filter)
      filter.is_a?(Queries::WorkPackages::Filter::SubprojectFilter)
    end

    def detect_subproject_filter(filters)
      filters.detect { |filter| subproject_filter?(filter) }
    end

    shared_examples_for 'adds a subproject id filter' do |operator|
      it "does not add a visible subproject filter" do
        expect(detect_subproject_filter(query.filters)).to be_nil
      end

      it "adds a #{operator} subproject_id filter to the statement" do
        added_filter = detect_subproject_filter(query.send(:statement_filters))
        expect(added_filter).to be_present
        expect(added_filter.operator).to eq operator
      end
    end

    shared_examples_for 'does not add a subproject id filter' do
      it 'does not add a second subproject id filter' do
        expect(query.filters.count).to eq(query.send(:statement_filters).count)

        expect(query.filters.select { |filter| subproject_filter?(filter) })
          .to match_array(query.send(:statement_filters).select { |filter| subproject_filter?(filter) })
      end
    end

    context 'when subprojects included settings active', with_settings: { display_subprojects_work_packages: true } do
      it_behaves_like 'adds a subproject id filter', '*'
    end

    context 'when subprojects included settings inactive', with_settings: { display_subprojects_work_packages: false } do
      it_behaves_like 'adds a subproject id filter', '!*'
    end

    context 'with a subproject filter added manually' do
      before do
        query.add_filter('subproject_id', '=', ['1234'])
      end

      it_behaves_like 'does not add a subproject id filter'
    end

    context 'with a only_subproject filter added manually' do
      before do
        query.add_filter('only_subproject_id', '=', ['1234'])
      end

      it_behaves_like 'does not add a subproject id filter'
    end

    context 'with a project filter added manually' do
      before do
        query.add_filter('project_id', '=', ['1234'])
      end

      it_behaves_like 'does not add a subproject id filter'
    end
  end
end
