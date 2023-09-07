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

describe RootSeeder,
         'standard edition',
         with_config: { edition: 'standard' },
         with_settings: { journal_aggregation_time_minutes: 0 } do
  before do
    allow($stdout).to receive(:puts) { |msg| Rails.logger.info(msg) }
  end

  it 'creates the demo data' do
    expect { described_class.new.do_seed! }.not_to raise_error

    expect(User.where(admin: true).count).to eq 1
    expect(Project.count).to eq 2
    expect(WorkPackage.count).to eq 36
    expect(Wiki.count).to eq 2
    expect(Query.having_views.count).to eq 8
    expect(View.where(type: 'work_packages_table').count).to eq 7
    expect(View.where(type: 'team_planner').count).to eq 1
    expect(Query.count).to eq 26
    expect(Projects::Status.count).to eq 2
    expect(Role.where(type: 'Role').count).to eq 5
    expect(GlobalRole.count).to eq 1

    perform_enqueued_jobs

    expect(ActionMailer::Base.deliveries)
      .to be_empty
  end
end
