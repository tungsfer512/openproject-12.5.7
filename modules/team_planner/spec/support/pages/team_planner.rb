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

require 'support/pages/page'
require 'support/pages/work_packages/work_package_cards'

module Pages
  class TeamPlanner < ::Pages::WorkPackageCards
    include ::Components::Autocompleter::NgSelectAutocompleteHelpers

    attr_reader :filters

    def initialize(project)
      super(project)

      @filters = ::Components::WorkPackages::Filters.new
    end

    def path
      new_project_team_planners_path(project)
    end

    def expect_title(title = 'Unnamed team planner')
      expect(page).to have_selector('.editable-toolbar-title--input') { |node| node.value == title }
    end

    def save_as(name)
      click_setting_item 'Save as'

      fill_in 'save-query-name', with: name

      click_button 'Save'

      expect_toast message: 'Successful creation.'
      expect_title name
    end

    def click_setting_item(label)
      ::Components::WorkPackages::SettingsMenu
        .new.open_and_choose(label)
    end

    def expect_empty_state(present: true)
      expect(page).to have_conditional_selector(present,
                                                '.op-team-planner--no-data',
                                                text: 'Add assignees to set up your team planner.')
    end

    def expect_view_mode(text)
      expect(page).to have_selector('[data-qa-selector="op-team-planner--view-select-dropdown"]', text:)

      param = {
        'Work week' => :resourceTimelineWorkWeek,
        '1-week' => :resourceTimelineWeek,
        '2-week' => :resourceTimelineTwoWeeks
      }[text]

      expect(page).to have_current_path(/cview=#{param}/)
    end

    def switch_view_mode(text)
      retry_block do
        find('[data-qa-selector="op-team-planner--view-select-dropdown"]').click

        within('#op-team-planner--view-select-dropdown') do
          click_button(text)
        end
      end

      expect_view_mode(text)
    end

    def expect_assignee(user, present: true)
      name = user.is_a?(User) ? user.name : user.to_s
      expect(page).to have_conditional_selector(present, '.fc-resource', text: name, wait: 10)
    end

    def add_item(assignee, start_date, end_date)
      script = <<~JS
        var event = new CustomEvent(
          'teamPlannerSelectDate',
          {
            detail: {
              assignee: arguments[0],
              start: arguments[1],
              end: arguments[2]
            }
          });

        document.dispatchEvent(event);
      JS

      page.execute_script(script, assignee, start_date, end_date)
      ::Pages::SplitWorkPackageCreate.new project:
    end

    def remove_assignee(user)
      page.find(%([data-qa-remove-assignee="#{user.id}"])).click
    end

    def within_lane(user, &)
      raise ArgumentError.new("Expected instance of principal") unless user.is_a?(Principal)

      page.within(lane(user), &)
    end

    def expect_event(work_package, present: true)
      if present
        expect(page).to have_selector('.fc-event', text: work_package.subject, wait: 10)
      else
        expect(page).not_to have_selector('.fc-event', text: work_package.subject)
      end
    end

    def expect_resizable(work_package, resizable: true)
      if resizable
        expect(page).to have_selector('.fc-event.fc-event-resizable', text: work_package.subject, wait: 10)
      else
        expect(page).to have_selector('.fc-event:not(.fc-event-resizable)', text: work_package.subject, wait: 10)
      end
    end

    def add_assignee(name)
      click_add_user
      page.find('[data-qa-selector="tp-add-assignee"] input')
      search_user_to_add name
      select_user_to_add name
    end

    def click_add_user
      # Close the existing, if it is open
      is_open = page.all('[data-qa-selector="tp-add-assignee"] input').first
      page.find('[data-qa-selector="tp-assignee-add-button"]').click unless is_open
    end

    def select_user_to_add(name)
      select_autocomplete page.find('[data-qa-selector="tp-add-assignee"]'),
                          query: name,
                          results_selector: 'body'
    end

    def search_user_to_add(name)
      search_autocomplete page.find('[data-qa-selector="tp-add-assignee"]'),
                          query: name,
                          results_selector: 'body'
    end

    def change_wp_date_by_resizing(work_package, number_of_days:, is_start_date:)
      wp_strip = event(work_package)

      page
        .driver
        .browser
        .action
        .move_to(wp_strip.native)
        .perform

      resizer = is_start_date ? wp_strip.find('.fc-event-resizer-start') : wp_strip.find('.fc-event-resizer-end')

      drag_by_pixel(element: resizer, by_x: number_of_days * 180, by_y: 0) unless resizer.nil?
    end

    def drag_wp_by_pixel(work_package, by_x, by_y)
      source = event(work_package)

      drag_by_pixel(element: source, by_x:, by_y:)
    end

    def drag_wp_to_lane(work_package, user)
      wp_strip = event(work_package)
      lane = lane(user)

      drag_by_pixel(element: wp_strip, by_x: 0, by_y: y_distance(from: wp_strip, to: lane))
    end

    def drag_to_remove_dropzone(work_package, expect_removable: true)
      retry_block do
        source = event(work_package)
        start_dragging(source)
      end

      # Move the footer first to signal we're dragging something
      footer = find('[data-qa-selector="op-team-planner-footer"]')
      drag_element_to(footer)

      sleep 1

      dropzone = find('[data-qa-selector="op-team-planner-dropzone"]')
      drag_element_to(dropzone)

      if expect_removable
        expect(page).to have_selector('span', text: I18n.t('js.team_planner.drag_here_to_remove'))
      else
        expect(page).to have_selector('span', text: I18n.t('js.team_planner.cannot_drag_here'))
      end

      drag_release

      if expect_removable
        expect_and_dismiss_toaster(message: "Successful update.")
      else
        expect_no_toaster
      end

      sleep 1
      expect_event(work_package, present: !expect_removable)
    end

    def event(work_package)
      page.find('.fc-event', text: work_package.subject)
    end

    def lane(user)
      type = ::API::V3::Principals::PrincipalType.for(user)
      href = ::API::V3::Utilities::PathHelper::ApiV3Path.send(type, user.id)

      page.find(%(.fc-timeline-lane[data-resource-id="#{href}"]))
    end

    def expect_wp_not_resizable(work_package)
      expect(page).to have_selector('.fc-event:not(.fc-event-resizable)', text: work_package.subject)
    end

    def expect_wp_not_draggable(work_package)
      expect(page).to have_selector('.fc-event:not(.fc-event-draggable)', text: work_package.subject)
    end

    def expect_no_menu_item(name)
      expect(page).not_to have_selector('.op-sidemenu--item-title', text: name)
    end

    def y_distance(from:, to:)
      y_center(to) - y_center(from)
    end

    def y_center(element)
      element.native.location.y + (element.native.size.height / 2)
    end

    def wait_for_loaded
      expect(page).to have_selector('.op-team-planner--wp-loading-skeleton')

      retry_block do
        raise "Should not be there" if page.has_selector?('.op-team-planner--wp-loading-skeleton')

        sleep 5
      end
    end
  end
end
