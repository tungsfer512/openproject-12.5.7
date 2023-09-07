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

describe 'Help menu items' do
  let(:user) { create(:admin) }
  let(:help_item) { find('.op-app-help .op-app-menu--item-action') }

  before do
    login_as user
  end

  describe 'When force_help_link is not set', js: true do
    it 'renders a dropdown' do
      visit home_path

      help_item.click
      expect(page).to have_selector('.op-app-help .op-menu--item-action',
                                    text: I18n.t('homescreen.links.user_guides'))
    end
  end

  describe 'When force_help_link is set', js: true do
    let(:custom_url) { 'https://mycustomurl.example.org/' }

    before do
      allow(OpenProject::Configuration).to receive(:force_help_link)
        .and_return custom_url
    end

    it 'renders a link' do
      visit home_path

      expect(help_item[:href]).to eq(custom_url)
      expect(page).not_to have_selector('.op-app-help .op-app-menu--dropdown', visible: false)
    end
  end
end
