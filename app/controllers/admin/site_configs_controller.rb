# frozen_string_literal: true

module Admin
  class SiteConfigsController < Admin::ApplicationController
    before_action :set_setting, only: %i[edit update]

    def index
    end

    def edit
    end

    def update
      if @site_config.value == setting_param[:value]
        return redirect_to admin_site_configs_path
      end

      @site_config.value = setting_param[:value].strip
      if @site_config.save
        if @site_config.require_restart?
          Setting.require_restart = true
        end

        redirect_to admin_site_configs_path, notice: "Update successfully."
      else
        render "edit"
      end
    end

    def set_setting
      @site_config = Setting.find_by(var: params[:id]) || Setting.new(var: params[:id])
    end

    private

    def setting_param
      params[:setting].permit!
    end
  end
end
