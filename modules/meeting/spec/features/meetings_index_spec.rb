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

require_relative '../support/pages/meetings/index'

describe 'Meetings' do
  let(:project) { create(:project, enabled_module_names: %w[meetings]) }
  let(:other_project) { create(:project, enabled_module_names: %w[meetings]) }
  let(:role) { create(:role, permissions:) }
  let(:permissions) { %i(view_meetings) }
  let(:user) do
    create(:user) do |user|
      [project, other_project].each do |p|
        create(:member,
               project: p,
               principal: user,
               roles: [role])
      end
    end
  end

  let(:meeting) do
    create(:meeting, project:, title: 'Awesome meeting today!', start_time: Time.current)
  end
  let(:tomorrows_meeting) do
    create(:meeting, project:, title: 'Awesome meeting tomorrow!', start_time: 1.day.from_now)
  end
  let(:yesterdays_meeting) do
    create(:meeting, project:, title: 'Awesome meeting yesterday!', start_time: 1.day.ago)
  end
  let!(:other_project_meeting) do
    create(:meeting, project: other_project, title: 'Awesome other project meeting!')
  end
  let(:meetings_page) { Pages::Meetings::Index.new(project) }

  before do
    login_as(user)
  end

  it 'visiting page via menu with no meetings' do
    meetings_page.navigate_by_menu

    meetings_page.expect_no_meetings_listed
  end

  it 'visiting page with 1 meeting listed' do
    meeting
    meetings_page.visit!

    meetings_page.expect_meetings_listed(meeting)
  end

  it 'visiting page with pagination', with_settings: { per_page_options: '1' } do
    meeting
    tomorrows_meeting
    yesterdays_meeting

    # Jumps to today's meeting if not specified differently
    meetings_page.visit!
    meetings_page.expect_meetings_listed(meeting)
    meetings_page.expect_meetings_not_listed(tomorrows_meeting, yesterdays_meeting)

    meetings_page.expect_to_be_on_page(2)

    # Sorted by start_time ascending
    meetings_page.to_page(1)
    meetings_page.expect_meetings_listed(tomorrows_meeting)
    meetings_page.expect_meetings_not_listed(meeting, yesterdays_meeting)

    meetings_page.to_page(3)
    meetings_page.expect_meetings_listed(yesterdays_meeting)
    meetings_page.expect_meetings_not_listed(meeting, tomorrows_meeting)

    # The 'today' link will navigate back to today
    meetings_page.to_today

    meetings_page.expect_meetings_listed(meeting)
    meetings_page.expect_meetings_not_listed(tomorrows_meeting, yesterdays_meeting)

    meetings_page.expect_to_be_on_page(2)
  end
end
