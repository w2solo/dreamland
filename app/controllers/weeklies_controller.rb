# frozen_string_literal: true

class WeekliesController < ApplicationController
  def show
    @digest = WeeklyDigest.find(params[:id])
    @page_title = @digest.title

    respond_to do |format|
      format.html
      format.rss { render layout: false }
    end
  end
end
