# frozen_string_literal: true

class ProductsController < ApplicationController
  before_action :authenticate_user!, only: %i[new create edit update]
  load_and_authorize_resource except: %i[index]
  before_action :set_product, only: %i[edit update]

  def index
    authorize! :read, Product
    @this_week_products = Product.this_week.includes(:user, :topic).to_a
    earlier = Product.launched.includes(:user, :topic).by_launch
    ids = @this_week_products.map(&:id)
    earlier = earlier.where.not(id: ids) if ids.any?
    @earlier_products = earlier.page(params[:page])
    @page_title = t("menu.products")
    @sidebar_products = Product.this_week.includes(:user, :topic).limit(4)
  end

  def show
    if @product.topic
      redirect_to @product.topic
    else
      render_404
    end
  end

  def new
    @product = current_user.products.new(status: :shipped)
  end

  def create
    @product = current_user.products.new(product_params.except(:body))
    @product.body = product_params[:body]
    if @product.publish
      redirect_to @product.topic, notice: t("products.create_success")
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @product.update_launch(product_params.to_h.symbolize_keys)
      redirect_to @product.topic || products_path, notice: t("products.update_success")
    else
      render :edit
    end
  end

  private

  def set_product
    @product = Product.find(params[:id])
  end

  def product_params
    permitted = params.require(:product).permit(:name, :tagline, :url, :cover, :cover_cache, :status, :body)
    permitted.delete(:cover) if permitted[:cover].blank?
    permitted
  end
end
