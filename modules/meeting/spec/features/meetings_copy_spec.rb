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

describe 'Meetings copy', js: true do
  let(:project) { create(:project, enabled_module_names: %w[meetings]) }
  let(:user) do
    create(:user,
           member_in_project: project,
           member_with_permissions: permissions).tap do |u|
      u.pref[:time_zone] = 'UTC'

      u.save!
    end
  end
  let(:other_user) do
    create(:user,
           member_in_project: project,
           member_with_permissions: permissions)
  end
  let(:permissions) { %i[view_meetings create_meetings] }

  let(:agenda_text) { "We will talk" }
  let!(:meeting) do
    create(:meeting,
           author: other_user,
           project:,
           title: 'Awesome meeting!',
           location: 'Meeting room',
           duration: 1.5,
           start_time: DateTime.parse("2013-03-27 18:55:00")).tap do |m|
      create(:meeting_agenda, meeting: m, text: agenda_text)
      m.participants.build(user: other_user, attended: true)
    end
  end

  before do
    login_as(user)
  end

  it 'copying a meeting' do
    visit meetings_path(project)

    click_link meeting.title

    within '.meeting--main-toolbar' do
      expect(page)
        .to have_link 'Copy'

      SeleniumHubWaiter.wait
      click_link 'Copy'
    end

    expect(page)
      .to have_field 'Title', with: meeting.title
    expect(page)
      .to have_field 'Location', with: meeting.location
    expect(page)
      .to have_field 'Duration', with: meeting.duration
    expect(page)
      .to have_field 'Start date', with: "2013-03-27"
    expect(page)
      .to have_field 'Time', with: "18:55"

    SeleniumHubWaiter.wait
    click_button "Create"

    # Be on the new meeting's page with copied over attributes
    expect(current_path)
      .not_to eql meeting_path(meeting.id)

    expect(page)
      .to have_content("Added by #{user.name}")

    expect(page)
      .to have_content("Meeting: #{meeting.title}")
    expect(page)
      .to have_content("Time: 03/27/2013 06:55 PM - 08:25 PM (GMT+00:00) UTC")
    expect(page)
      .to have_content("Location: #{meeting.location}")

    # Copies the invitees
    expect(page)
      .to have_content "Invitees: #{other_user.name}"

    # Does not copy the attendees
    expect(page)
      .to have_no_content "Attendees: #{other_user.name}"

    expect(page)
      .to have_content "Attendees:"

    # Copies the agenda
    SeleniumHubWaiter.wait
    click_link "Agenda"

    expect(page)
      .to have_content agenda_text

    # Adds an entry to the history
    SeleniumHubWaiter.wait
    click_link "History"

    expect(page)
      .to have_content("Copied from Meeting ##{meeting.id}")
  end
end
