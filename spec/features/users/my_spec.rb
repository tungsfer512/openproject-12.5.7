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

describe 'my',
         js: true, with_config: { session_store: :active_record_store } do
  let(:user_password) { 'bob' * 4 }
  let(:user) do
    create(:user,
           mail: 'old@mail.com',
           login: 'bob',
           password: user_password,
           password_confirmation: user_password)
  end

  ##
  # Expecations for a successful account change
  def expect_changed!
    expect(page).to have_content I18n.t(:notice_account_updated)
    expect(page).to have_content I18n.t(:notice_account_other_session_expired)

    # expect session to be removed
    expect(Sessions::UserSession.for_user(user).where(session_id: 'other').count).to eq 0

    user.reload
    expect(user.mail).to eq 'foo@mail.com'
    expect(user.name).to eq 'Foo Bar'
  end

  before do
    login_as(user)

    # Create dangling session
    session = Sessions::SqlBypass.new data: { user_id: user.id }, session_id: 'other'
    session.save

    expect(Sessions::UserSession.for_user(user).where(session_id: 'other').count).to eq 1
  end

  context 'user' do
    describe '#account' do
      let(:dialog) { Components::PasswordConfirmationDialog.new }

      before do
        visit my_account_path

        fill_in 'user[mail]', with: 'foo@mail.com'
        fill_in 'user[firstname]', with: 'Foo'
        fill_in 'user[lastname]', with: 'Bar'
        click_on 'Save'
      end

      context 'when confirmation disabled',
              with_config: { internal_password_confirmation: false } do
        it 'does not request confirmation' do
          expect_changed!
        end
      end

      context 'when confirmation required',
              with_config: { internal_password_confirmation: true } do
        it 'requires the password for a regular user' do
          dialog.confirm_flow_with(user_password)
          expect_changed!
        end

        it 'declines the change when invalid password is given' do
          dialog.confirm_flow_with(user_password + 'INVALID', should_fail: true)

          user.reload
          expect(user.mail).to eq('old@mail.com')
        end

        context 'as admin' do
          shared_let(:admin) { create(:admin) }
          let(:user) { admin }

          it 'requires the password' do
            dialog.confirm_flow_with('adminADMIN!')
            expect_changed!
          end
        end
      end
    end

    describe 'settings' do
      context 'with a default time zone', with_settings: { user_default_timezone: 'Asia/Tokyo' } do
        it 'can override a time zone' do
          expect(user.pref.time_zone).to eq 'Asia/Tokyo'
          visit my_settings_path

          expect(page).to have_select 'pref_time_zone', selected: '(GMT+09:00) Tokyo'
          select '(GMT+01:00) Paris', from: 'pref_time_zone'
          click_on 'Save'

          expect(page).to have_select 'pref_time_zone', selected: '(GMT+01:00) Paris'
          expect(user.pref.time_zone).to eq 'Europe/Paris'
        end
      end
    end

    it 'in Access Tokens they can generate their API key' do
      visit my_access_token_path
      expect(page).to have_content 'Missing API access key'
      find(:xpath, "//tr[contains(.,'API')]/td/a", text: 'Generate').click

      expect(page).to have_content 'A new API token has been generated. Your access token is'

      User.current.reload
      visit my_access_token_path

      expect(page).not_to have_content 'Missing API access key'
    end

    it 'in Access Tokens they can generate their RSS key' do
      visit my_access_token_path
      expect(page).to have_content 'Missing RSS access key'
      find(:xpath, "//tr[contains(.,'RSS')]/td/a", text: 'Generate').click

      expect(page).to have_content 'A new RSS token has been generated. Your access token is'

      User.current.reload
      visit my_access_token_path

      expect(page).not_to have_content 'Missing RSS access key'
    end
  end
end
