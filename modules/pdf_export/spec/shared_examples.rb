shared_examples_for "should let you create a configuration" do
  before do
    post 'create', params:
  end

  it { expect(response).to redirect_to action: 'index' }
  it { expect(flash[:notice]).to eq(I18n.t(:notice_successful_create)) }
end

shared_examples_for "should not let you create a configuration" do
  before do
    post 'create', params:
  end

  it { expect(response).to render_template('new') }
  it { expect(assigns(:config).errors.messages).not_to be_empty }
end
