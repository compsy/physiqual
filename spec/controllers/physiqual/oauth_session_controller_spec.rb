require 'rails_helper'
module Physiqual
  describe OauthSessionController do
    let(:user) { FactoryGirl.create(:physiqual_user) }
    # routes { Physiqual::Engine.routes }

    describe 'before filters' do
      it 'calls the check_token method when calling index' do
        session['physiqual_user_id'] = user.user_id
        expect(subject).to receive(:check_token) { fail(StandardError, 'stop_execution') }
        expect { get :index }.to raise_error('stop_execution')
      end

      it 'calls the find_or_create_token method when calling authorize' do
        expect(subject).to receive(:find_or_create_token) { fail(StandardError, 'stop_execution') }
        expect { get :authorize }.to raise_error('stop_execution')
      end

      it 'calls the find_token method when calling callback' do
        expect(subject).to receive(:find_token) { fail(StandardError, 'stop_execution') }
        expect { get :callback }.to raise_error('stop_execution')
      end
    end

    describe 'authorize' do
      it 'heads 404 if no provider is given' do
        get :authorize
        expect(response.status).to eq(404)
      end

      describe 'redirects to the correct google url' do
        before :each do
          expect(subject).to receive(:current_user).and_return(user)
          get :authorize, provider: GoogleToken.csrf_token
        end

        it 'has the correct base url' do
          expect(response).to redirect_to(/\A#{GoogleToken.oauth_site}#{GoogleToken.authorize_url}/)
        end

        it 'adds the correct redirect url' do
          url = CGI.escape subject.callback_oauth_session_index_url(provider: GoogleToken.csrf_token)
          expect(response).to redirect_to(/redirect_uri=#{url}/)
        end

        it 'adds the correct state' do
          expect(response).to redirect_to(/state=#{GoogleToken.csrf_token}/)
        end

        it 'adds the correct scope' do
          GoogleToken.scope.split(' ').each do |scope|
            expect(response).to redirect_to(/#{CGI.escape scope}/)
          end
        end
      end
      describe 'redirects to the correct fitbit url' do
        before :each do
          expect(subject).to receive(:current_user).and_return(user)
          get :authorize, provider: FitbitToken.csrf_token
        end

        it 'has the correct base url' do
          expect(response).to redirect_to(/\A#{FitbitToken.authorize_url}/)
        end

        it 'adds the correct redirect url' do
          url = CGI.escape subject.callback_oauth_session_index_url(provider: FitbitToken.csrf_token)
          expect(response).to redirect_to(/redirect_uri=#{url}/)
        end

        it 'adds the correct state' do
          expect(response).to redirect_to(/state=#{FitbitToken.csrf_token}/)
        end

        it 'adds the correct scope' do
          FitbitToken.scope.split(' ').each do |scope|
            expect(response).to redirect_to(/#{scope}/)
          end
        end
      end
    end

    describe 'check_token' do
      let(:provider) { GoogleToken.csrf_token }
      before :each do
        expect(subject).to receive(:current_user).and_return(user)
        subject.params[:state] = provider
      end

      after :each do
        subject.send(:check_token)
      end

      describe 'without tokens' do
        it 'redirects to the authorize path if the user does not have tokens' do
          expect(subject).to receive(:redirect_to).with(subject.authorize_oauth_session_index_path(provider: provider))
        end

        it 'redirects to the authorize path if the user only has incomplete token' do
          user.google_tokens.create
          user.google_tokens.each { |tok| expect(tok.complete?).to be_falsey }

          expect(subject).to receive(:redirect_to).with(subject.authorize_oauth_session_index_path(provider: provider))
        end
      end

      describe 'with tokens' do
        before :each do
          # If there is a token, the current user is called twice.
          expect(subject).to receive(:current_user).and_return(user)
        end

        after :each do
          user.google_tokens.each { |tok| expect(tok.complete?).to be_truthy }
        end

        it 'redirects to the authorize path if the user only has incomplete token' do
          token = FactoryGirl.build(:physiqual_token, :google, physiqual_user: user)
          user.physiqual_tokens << token
          user.save!
          user.google_tokens.each { |tok| expect(tok.expired?).to be_falsey }
        end

        it 'refreshes all expired tokens, also if one provider is called' do
          token = FactoryGirl.build(:physiqual_token, :google, valid_until: 10.minutes.ago, physiqual_user: user)
          token2 = FactoryGirl.build(:physiqual_token, :fitbit, valid_until: 10.minutes.ago, physiqual_user: user)
          user.physiqual_tokens << token
          user.physiqual_tokens << token2

          user.save!
          user.physiqual_tokens.each { |tok| expect(tok.expired?).to be_truthy }
          user.physiqual_tokens.each { |tok| expect(tok).to receive(:refresh!).and_return(true) }
        end
      end
    end

    describe 'set_token' do
      let(:provider) { GoogleToken.csrf_token }

      it 'raise an error if there is no provider' do
        expect(subject).to receive(:current_user).and_return(user)
        expect { subject.send(:find_or_create_token) }.to raise_error(Errors::ServiceProviderNotFoundError)
      end

      it 'raise an error if there is no user' do
        subject.params[:provider] = provider
        expect { subject.send(:find_or_create_token) }.to raise_error(Errors::UserIdNotFoundError)
      end

      it 'sets a new token if there are no tokens' do
        expect(subject).to receive(:current_user).and_return(user)
        subject.params[:provider] = provider
        subject.send(:find_or_create_token)
        expect(subject.instance_variable_get(:@token)).to_not be_nil
      end

      it 'sets an existing token, according to the provider provided ' do
        expect(subject).to receive(:current_user).and_return(user)
        token = FactoryGirl.build(:physiqual_token, :google, physiqual_user: user)
        user.physiqual_tokens << token
        user.save!

        subject.params[:provider] = provider
        subject.send(:find_or_create_token)
        expect(subject.instance_variable_get(:@token)).to_not be_nil
      end
    end

    describe 'token' do
      let(:provider) { GoogleToken.csrf_token }

      before :each do
        expect(subject).to receive(:current_user).and_return(user)
        subject.params[:provider] = provider
      end

      it 'should set the @ token variable with ' do
        token = FactoryGirl.create(:google_token, physiqual_user: user)
        subject.send(:find_token)
        expect(subject.instance_variable_get(:@token)).to eq(token)
      end

      it 'should raise an error if no tokens are present' do
        expect { subject.send(:find_token) }.to raise_error(Errors::NoTokenExistsError)
      end
    end

    describe 'get_or_create_token' do
      let(:google_token) { FactoryGirl.build(:google_token, physiqual_user: user) }
      let(:fitbit_token) { FactoryGirl.build(:fitbit_token, physiqual_user: user) }

      it 'returns the token if it exists' do
        result = subject.send(:get_or_create_token, [google_token])
        expect(result).to eq(google_token)
      end

      it 'creates a token with the correct class if it does not exist' do
        tokens = user.google_tokens
        result = subject.send(:get_or_create_token, tokens)
        expect(result).to be_a(Token)
        expect(result).to be_a(GoogleToken)

        tokens = user.fitbit_tokens
        result = subject.send(:get_or_create_token, tokens)
        expect(result).to be_a(Token)
        expect(result).to be_a(FitbitToken)
      end
    end

    describe 'sanitize_params' do
      it 'removes providers which are not correct' do
        fake_provider = 'fake-provider'
        subject.params[:provider] = fake_provider
        subject.send(:sanitize_params)
        expect(subject.params[:provider]).to be_nil
      end

      it 'leaves providers which are correct' do
        provider = GoogleToken.csrf_token
        subject.params[:provider] = provider
        subject.send(:sanitize_params)
        expect(subject.params[:provider]).to include(provider)
      end
    end
  end
end
