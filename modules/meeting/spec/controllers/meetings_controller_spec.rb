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

require File.dirname(__FILE__) + '/../spec_helper'

describe MeetingsController do
  let(:project) { create(:project) }

  before do
    allow(Project).to receive(:find).and_return(project)

    allow(@controller).to receive(:authorize)
    allow(@controller).to receive(:check_if_login_required)
  end

  describe 'GET' do
    describe 'index' do
      before do
        @ms = [build_stubbed(:meeting),
               build_stubbed(:meeting),
               build_stubbed(:meeting)]
        allow(@ms).to receive(:from_tomorrow).and_return(@ms)

        allow(project).to receive(:meetings).and_return(@ms)
        %i[with_users_by_date page per_page].each do |meth|
          expect(@ms).to receive(meth).and_return(@ms)
        end
        @grouped = double('grouped')
        expect(Meeting).to receive(:group_by_time).with(@ms).and_return(@grouped)
      end

      describe 'html' do
        before do
          get 'index', params: { project_id: project.id }
        end

        it { expect(response).to be_successful }
        it { expect(assigns(:meetings_by_start_year_month_date)).to eql @grouped }
      end
    end

    describe 'show' do
      before do
        @m = build_stubbed(:meeting, project:, agenda: nil)
        allow(Meeting).to receive_message_chain(:includes, :find).and_return(@m)
      end

      describe 'html' do
        before do
          get 'show', params: { id: @m.id }
        end

        it { expect(response).to be_successful }
      end
    end

    describe 'new' do
      before do
        allow(Project).to receive(:find).and_return(project)
        @m = build_stubbed(:meeting)
        allow(Meeting).to receive(:new).and_return(@m)
      end

      describe 'html' do
        before do
          get 'new',  params: { project_id: project.id }
        end

        it { expect(response).to be_successful }
        it { expect(assigns(:meeting)).to eql @m }
      end
    end

    describe 'edit' do
      before do
        @m = build_stubbed(:meeting, project:)
        allow(Meeting).to receive_message_chain(:includes, :find).and_return(@m)
      end

      describe 'html' do
        before do
          get 'edit', params: { id: @m.id }
        end

        it { expect(response).to be_successful }
        it { expect(assigns(:meeting)).to eql @m }
      end
    end

    describe 'create' do
      render_views

      before do
        allow(Project).to receive(:find).and_return(project)
        post :create,
             params: {
               project_id: project.id,
               meeting: {
                 title: 'Foobar',
                 duration: '1.0'
               }.merge(params)
             }
      end

      describe 'invalid start_date' do
        let(:params) do
          {
            start_date: '-',
            start_time_hour: '10:00'
          }
        end

        it 'renders an error' do
          expect(response.status).to be 200
          expect(response).to render_template :new
          expect(response.body)
            .to have_selector '#errorExplanation li',
                              text: "Start date " +
                                    I18n.t('activerecord.errors.messages.not_an_iso_date')
        end
      end

      describe 'invalid start_time_hour' do
        let(:params) do
          {
            start_date: '2015-06-01',
            start_time_hour: '-'
          }
        end

        it 'renders an error' do
          expect(response.status).to be 200
          expect(response).to render_template :new
          expect(response.body)
            .to have_selector '#errorExplanation li',
                              text: "Starting time " +
                                    I18n.t('activerecord.errors.messages.invalid_time_format')
        end
      end
    end
  end
end
