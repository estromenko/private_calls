defmodule PrivateCallsWeb.Router do
  use PrivateCallsWeb, :router

  import PrivateCallsWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PrivateCallsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PrivateCallsWeb do
    pipe_through :browser

    get "/", LandingController, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", PrivateCallsWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:private_calls, :dev_routes) do
    scope "/dev" do
      pipe_through :browser
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", PrivateCallsWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{PrivateCallsWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", PrivateCallsWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{PrivateCallsWeb.UserAuth, :ensure_authenticated}] do
      live "/chats", MainLive.Index
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
    end
  end

  scope "/admin", PrivateCallsWeb do
    import Phoenix.LiveDashboard.Router

    pipe_through [:browser, :require_authenticated_user, :require_superuser]

    live_session :require_superuser,
      on_mount: [{PrivateCallsWeb.UserAuth, :ensure_authenticated}] do
      live "/chats", ChatLive.Index, :index
      live "/chats/new", ChatLive.Index, :new
      live "/chats/:id/edit", ChatLive.Index, :edit
      live "/chats/:id", ChatLive.Show, :show
      live "/chats/:id/show/edit", ChatLive.Show, :edit
    end

    live_dashboard "/dashboard",
      metrics: PrivateCallsWeb.Telemetry,
      ecto_repos: [PrivateCalls.Repo]
  end

  scope "/", PrivateCallsWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{PrivateCallsWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end
end
