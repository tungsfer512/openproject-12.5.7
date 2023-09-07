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
module DemoData
  class WorkPackageBoardSeeder < Seeder
    attr_accessor :project, :key

    include ::DemoData::References

    def initialize(project, key)
      self.project = project
      self.key = key
    end

    def seed_data!
      # Seed only for those projects that provide a `kanban` key, i.e. 'demo-project' in standard edition.
      if project_has_data_for?(key, 'boards.kanban')
        print_status '    ↳ Creating demo status board' do
          seed_kanban_board
        end
      end

      if project_has_data_for?(key, 'boards.basic')
        print_status '    ↳ Creating demo basic board' do
          seed_basic_board
        end
      end

      if project_has_data_for?(key, 'boards.parent_child')
        print_status '    ↳ Creating demo parent child board' do
          seed_parent_child_board
        end
      end
    end

    private

    def seed_kanban_board
      board = ::Boards::Grid.new(project:)

      board.name = project_data_for(key, 'boards.kanban.name')
      board.options = { 'type' => 'action', 'attribute' => 'status', 'highlightingMode' => 'priority' }

      set_board_filters(board)

      board.widgets = seed_kanban_board_queries.each_with_index.map do |query, i|
        Grids::Widget.new start_row: 1, end_row: 2,
                          start_column: i + 1, end_column: i + 2,
                          options: { query_id: query.id,
                                     filters: [{ status: { operator: '=', values: query.filters[0].values } }] },
                          identifier: 'work_package_query'
      end

      board.column_count = board.widgets.count
      board.row_count = 1

      board.save!

      Setting.boards_demo_data_available = 'true'
    end

    def set_board_filters(board)
      if project_data_for(key, 'boards.kanban.filters').present?
        filters_conf = project_data_for(key, 'boards.kanban.filters')
        board.options[:filters] = []
        filters_conf.each do |filter|
          if filter[:type]
            type = Type.find_by(name: translate_with_base_url(filter[:type]))
            board.options[:filters] << { type: { operator: '=', values: [type.id.to_s] } }
          end
        end
      end
    end

    def seed_kanban_board_queries
      admin = User.admin.first

      status_names = ['New', 'In progress', 'Closed', 'Rejected']
      statuses = Status.where(name: status_names).to_a

      if statuses.size < status_names.size
        raise StandardError.new "Not all statuses needed for seeding a KANBAN board are present. Check that they get seeded."
      end

      statuses.to_a.map do |status|
        Query.new_default(project:, user: admin).tap do |query|
          # Make it public so that new members can see it too
          query.public = true

          query.name = status.name
          # Set filter by this status
          query.add_filter('status_id', '=', [status.id])

          # Set manual sort filter
          query.sort_criteria = [[:manual_sorting, 'asc']]

          query.save!
        end
      end
    end

    def seed_basic_board
      board = ::Boards::Grid.new(project:)
      board.name = project_data_for(key, 'boards.basic.name')
      board.options = { 'highlightingMode' => 'priority' }

      board.widgets = seed_basic_board_queries.each_with_index.map do |query, i|
        Grids::Widget.new start_row: 1, end_row: 2,
                          start_column: i + 1, end_column: i + 2,
                          options: { query_id: query.id,
                                     filters: [{ manualSort: { operator: 'ow', values: [] } }] },
                          identifier: 'work_package_query'
      end

      board.column_count = board.widgets.count
      board.row_count = 1

      board.save!
    end

    def seed_basic_board_queries
      admin = User.admin.first

      wps = if project.name === 'Scrum project'
              scrum_query_work_packages
            else
              basic_query_work_packages
            end

      lists = [{ name: 'Wish list', wps: wps[0] },
               { name: 'Short list', wps: wps[1] },
               { name: 'Prio list for today', wps: wps[2] },
               { name: 'Never', wps: wps[3] }]

      lists.map do |list|
        Query.new(project:, user: admin).tap do |query|
          # Make it public so that new members can see it too
          query.public = true
          query.include_subprojects = true

          query.name = list[:name]

          # Set manual sort filter
          query.add_filter('manual_sort', 'ow', [])
          query.sort_criteria = [[:manual_sorting, 'asc']]

          list[:wps].each_with_index do |wp_id, i|
            query.ordered_work_packages.build(work_package_id: wp_id, position: i)
          end

          query.save!
        end
      end
    end

    def scrum_query_work_packages
      [
        [WorkPackage.find_by(subject: 'New website').id,
         WorkPackage.find_by(subject: 'SSL certificate').id,
         WorkPackage.find_by(subject: 'Choose a content management system').id],
        [WorkPackage.find_by(subject: 'New login screen').id],
        [WorkPackage.find_by(subject: 'Set-up Staging environment').id],
        [WorkPackage.find_by(subject: 'Wrong hover color').id]
      ]
    end

    def basic_query_work_packages
      [
        [WorkPackage.find_by(subject: 'Setup conference website').id,
         WorkPackage.find_by(subject: 'Upload presentations to website').id],
        [WorkPackage.find_by(subject: 'Invite attendees to conference').id],
        [WorkPackage.find_by(subject: 'Set date and location of conference').id],
        []
      ]
    end

    def seed_parent_child_board
      board = ::Boards::Grid.new(project:)

      board.name = project_data_for(key, 'boards.parent_child.name')
      board.options = { 'type' => 'action', 'attribute' => 'subtasks' }

      board.widgets = seed_parent_child_board_queries.each_with_index.map do |query, i|
        Grids::Widget.new start_row: 1, end_row: 2,
                          start_column: i + 1, end_column: i + 2,
                          options: { query_id: query.id,
                                     filters: [{ parent: { operator: '=', values: query.filters[1].values } }] },
                          identifier: 'work_package_query'
      end

      board.column_count = board.widgets.count
      board.row_count = 1

      board.save!

      Setting.boards_demo_data_available = 'true'
    end

    def seed_parent_child_board_queries
      admin = User.admin.first

      parents = [WorkPackage.find_by(subject: 'Organize open source conference'),
                 WorkPackage.find_by(subject: 'Follow-up tasks')]

      parents.map do |parent|
        Query.new_default(project:, user: admin).tap do |query|
          # Make it public so that new members can see it too
          query.public = true

          query.name = parent.subject
          # Set filter by this status
          query.add_filter('parent', '=', [parent.id])

          # Set manual sort filter
          query.sort_criteria = [[:manual_sorting, 'asc']]

          query.save!
        end
      end
    end
  end
end
