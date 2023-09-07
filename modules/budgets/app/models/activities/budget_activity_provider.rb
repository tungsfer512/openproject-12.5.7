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

class Activities::BudgetActivityProvider < Activities::BaseActivityProvider
  activity_provider_for type: 'budgets',
                        permission: :view_budgets

  def event_query_projection
    [
      activity_journal_projection_statement(:subject, 'budget_subject'),
      activity_journal_projection_statement(:project_id, 'project_id')
    ]
  end

  def event_type(_event)
    'budget'
  end

  def event_title(event)
    "#{I18n.t(:label_budget)} ##{event['journable_id']}: #{event['budget_subject']}"
  end

  def event_path(event)
    url_helpers.budget_path(url_helper_parameter(event))
  end

  def event_url(event)
    url_helpers.budget_url(url_helper_parameter(event))
  end

  private

  def url_helper_parameter(event)
    event['journable_id']
  end
end
