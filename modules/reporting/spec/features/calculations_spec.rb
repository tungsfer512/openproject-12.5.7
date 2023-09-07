require 'spec_helper'

describe 'Cost report calculations', js: true do
  let(:project) { create(:project) }
  let(:user) { create(:admin) }

  let(:work_package) { create(:work_package, project:) }
  let!(:hourly_rate1) { create(:default_hourly_rate, user:, rate: 1.00, valid_from: 1.year.ago) }
  let!(:hourly_rate2) { create(:default_hourly_rate, user:, rate: 5.00, valid_from: 2.years.ago) }
  let!(:hourly_rate3) { create(:default_hourly_rate, user:, rate: 10.00, valid_from: 3.years.ago) }

  let!(:time_entry1) do
    create(:time_entry,
           spent_on: 6.months.ago,
           user:,
           work_package:,
           project:,
           hours: 10)
  end
  let!(:time_entry2) do
    create(:time_entry,
           spent_on: 18.months.ago,
           user:,
           work_package:,
           project:,
           hours: 10)
  end
  let!(:time_entry3) do
    create(:time_entry,
           spent_on: 30.months.ago,
           user:,
           work_package:,
           project:,
           hours: 10)
  end

  before do
    login_as(user)
    visit '/cost_reports?set_filter=1'
  end

  it 'shows the correct calculations' do
    expect(page).to have_text '10.00' # 1 EUR x 10
    expect(page).to have_text '50.00' # 5 EUR x 10
    expect(page).to have_text '100.00' # 10 EUR x 10
    expect(page).to have_text '160.00'
  end
end
