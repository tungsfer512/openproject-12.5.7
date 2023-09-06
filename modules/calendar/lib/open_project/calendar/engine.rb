# OpenProject Calendar module
#
# Copyright (C) 2021 OpenProject GmbH
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

module OpenProject::Calendar
  class Engine < ::Rails::Engine
    engine_name :openproject_calendar

    include OpenProject::Plugins::ActsAsOpEngine

    register 'openproject-calendar',
             author_url: 'https://www.openproject.org',
             bundled: true,
             settings: {},
             name: 'OpenProject Calendar' do
      project_module :calendar_view, dependencies: :work_package_tracking do
        permission :view_calendar,
                   { 'calendar/calendars': %i[index show] },
                   dependencies: %i[view_work_packages],
                   contract_actions: { calendar: %i[read] }
        permission :manage_calendars,
                   { 'calendar/calendars': %i[index show new destroy] },
                   dependencies: %i[view_calendar add_work_packages edit_work_packages save_queries manage_public_queries],
                   contract_actions: { calendar: %i[create update destroy] }
      end

      menu :project_menu,
           :calendar_view,
           { controller: '/calendar/calendars', action: 'index' },
           caption: :label_calendar_plural,
           icon: 'icon2 icon-calendar',
           after: :work_packages

      menu :project_menu,
           :calendar_menu,
           { controller: '/calendar/calendars', action: 'index' },
           parent: :calendar_view,
           partial: 'calendar/calendars/menu',
           last: true,
           caption: :label_calendar_plural
    end

    add_view :WorkPackagesCalendar,
             contract_strategy: 'Calendar::Views::ContractStrategy'
  end
end
