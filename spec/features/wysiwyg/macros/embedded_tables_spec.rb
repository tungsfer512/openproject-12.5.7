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

describe 'Wysiwyg embedded work package tables',
         js: true do
  shared_let(:admin) { create(:admin) }
  let(:user) { admin }
  let(:type_task) { create(:type_task) }
  let(:type_bug) { create(:type_bug) }
  let(:project) do
    create(:project, types: [type_task, type_bug], enabled_module_names: %w[wiki work_package_tracking])
  end
  let(:editor) { Components::WysiwygEditor.new }
  let!(:wp_task) { create(:work_package, project:, type: type_task) }
  let!(:wp_bug) { create(:work_package, project:, type: type_bug) }

  let(:modal) { Components::WorkPackages::TableConfigurationModal.new }
  let(:filters) { Components::WorkPackages::TableConfiguration::Filters.new }
  let(:columns) { Components::WorkPackages::Columns.new }

  before do
    login_as(user)
  end

  describe 'in wikis' do
    describe 'creating a wiki page' do
      before do
        visit project_wiki_path(project, :wiki)
      end

      it 'can add and edit an embedded table widget' do
        editor.in_editor do |_container, editable|
          editor.insert_macro 'Embed work package table'

          modal.expect_open
          modal.switch_to 'Filters'
          filters.expect_filter_count 2
          filters.add_filter_by('Type', 'is (OR)', type_task.name)

          modal.switch_to 'Columns'
          columns.assume_opened
          columns.uncheck_all save_changes: false
          columns.add 'ID', save_changes: false
          columns.add 'Subject', save_changes: false
          columns.add 'Type', save_changes: false
          columns.expect_checked 'ID'
          columns.expect_checked 'Subject'
          columns.expect_checked 'Type'

          # Save widget
          modal.save

          # Find widget, click to show toolbar
          macro = editable.find('.ck-widget.op-uc-placeholder')
          macro.click

          # Edit widget again
          page.find('.ck-balloon-panel .ck-button', visible: :all, text: 'Edit').click

          modal.expect_open
          modal.switch_to 'Filters'
          filters.expect_filter_count 3
          modal.switch_to 'Columns'
          columns.assume_opened
          columns.expect_checked 'ID'
          columns.expect_checked 'Subject'
          columns.expect_checked 'Type'
          modal.cancel

          # Expect we can preview the table within ckeditor-augmented-textarea
          editor.within_enabled_preview do |preview_container|
            embedded_table = Pages::EmbeddedWorkPackagesTable.new preview_container
            embedded_table.expect_work_package_listed wp_task
            embedded_table.ensure_work_package_not_listed! wp_bug
          end
        end

        # Save wiki page
        click_on 'Save'

        expect(page).to have_selector('.flash.notice')

        embedded_table = Pages::EmbeddedWorkPackagesTable.new find('.wiki-content')
        embedded_table.expect_work_package_listed wp_task
        embedded_table.ensure_work_package_not_listed! wp_bug

        # Clicking on work package ID redirects
        full_view = embedded_table.open_full_screen_by_doubleclick wp_task
        full_view.ensure_page_loaded
      end
    end
  end
end
