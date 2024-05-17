require 'redcarpet'
require 'sanitize'
module ApplicationHelper
  def markdown(text)
    if text == nil
      return
    end
    renderer = Redcarpet::Render::HTML.new(hard_wrap: true, escape_html: false)
    options = {
      autolink: true,
      no_intra_emphasis: true,
      fenced_code_blocks: true,
      lax_html_blocks: true,
      strikethrough: true,
      superscript: true
    }
    raw_html = Redcarpet::Markdown.new(renderer, options).render(text).html_safe
    sanitize_html = Sanitize.fragment(raw_html, Sanitize::Config::RELAXED)
    sanitize_html.html_safe
  end

  def markdown_no_p(text)
    ret = markdown(text)
    ActiveSupport::SafeBuffer.new(Regexp.new('^<p>(.*)<\/p>$').match(ret)[1]) rescue ret
  end

  def markdown_no_html(text)
    if text == nil
      return
    end
    renderer = Redcarpet::Render::HTML.new(hard_wrap: true, escape_html: true)
    options = {
      autolink: true,
      no_intra_emphasis: true,
      fenced_code_blocks: true,
      lax_html_blocks: true,
      strikethrough: true,
      superscript: true
    }
    Redcarpet::Markdown.new(renderer, options).render(text).html_safe
  end

  def destroy_glyph
    return raw '<span class="glyphicon glyphicon-trash"></span>'
  end

  def edit_glyph
    return raw '<span class="fui-new"></span>'
  end

  def pin_glyph
    return raw '<span class="glyphicon glyphicon-pushpin"></span>'
  end

  def verdict_text(x)
    class_map = {
      "AC" => "text-success",
      "WA" => "text-danger",
      "TLE" => "text-info",
      "MLE" => "text-mle",
      "OLE" => "text-ole",
      "RE" => "text-warning",
      "SIG" => "text-sig",
      "queued" => "text-muted",
    }
    if class_map[x]
      return raw '<span class="' + class_map[x] + '">' + x + '</span>'
    else
      return x
    end
  end

  def help_icon(x)
    raw '<a href="' + x + '" style="color: inherit;" class="glyphicon glyphicon-question-sign"></a>'
  end

  def help_collapse_toggle(x, target)
    raw x + ' <a class="glyphicon glyphicon-question-sign" style="color: inherit;" data-toggle="collapse" href="#' + target + '" role="button" aria-expanded="false" aria-controls="collapseExample"></a>'
  end

  def alert_tag(opts={}, &block)
    dismissible = opts.fetch(:dismissible, true)
    cls = opts.fetch(:class, 'alert-info')
    cls += ' alert-dismissible' if dismissible
    cls = ' ' + cls if cls[0] != ' '
    ret = raw '<div class="alert' + cls + '" role="alert">'
    if dismissible
      ret += raw <<~HTML
      <button type="button" class="close" data-dismiss="alert">
        <span aria-hidden="true">&times;</span>
        <span class="sr-only">Close</span>
      </button>
      HTML
    end
    ret += capture(&block) + raw('</div>')
    concat(ret)
  end

  def score_str(x)
    number_with_precision(x, strip_insignificant_zeros: true, precision: 6)
  end

  def duration_text(x)
    mins = (x + 30) / 60
    if mins >= 24 * 60
      '%dd%d:%02d' % [mins / (24 * 60), mins / 60 % 24, mins % 60]
    else
      '%d:%02d' % [mins / 60 % 24, mins % 60]
    end
  end

  def ratio_text(ac, all)
    return "%.1f%%" % (100.0 * ac / all)
  end

  def page_title(title)
    title.empty? ? Rails.application.config.site_name : title
  end

  def set_page_title(title, site_name = nil)
    site_name ||= Rails.application.config.site_name
    if params[:page]
      @page_title = "#{title} - Page #{params[:page]}"
    else
      @page_title = title
    end
    @page_title = "#{@page_title} | #{site_name}"
    content_for :title, @page_title
  end

  def to_us(x)
    return x.to_i * 1000000 + x.usec
  end

  def notify_contest_channel(contest_id, user_id = nil)
    return unless contest_id
    ActionCable.server.broadcast("ranklist_update_#{contest_id}", {})
    if user_id.nil?
      ActionCable.server.broadcast("ranklist_update_#{contest_id}_global", {})
    else
      ActionCable.server.broadcast("ranklist_update_#{contest_id}_#{user_id}", {})
    end
  end

  def strip_contest_prefix(x)
    x = x + '/' if /^\/single_contest\/([0-9]+)$/.match(x)
    pat = /^\/single_contest\/([0-9]+)\//
    m1 = pat.match(request.original_fullpath)
    m2 = pat.match(x)
    return x unless m1 && m2 && m1[1] == m2[1]
    prefix = 'a://a'
    parsed = URI.parse(prefix + x)
    ret = URI.parse(prefix + x).route_from(prefix + request.original_fullpath).to_s
    ret = '?' if ret == '' && !request.query_string.empty?
    ret
  end

  def contest_adaptive_polymorphic_path(records, options = {})
    strip_prefix = options.delete(:strip_prefix)
    if @contest
      ret = polymorphic_path([@contest] + records, options)
      if @layout == :single_contest
        ret = ret.gsub(/^\/contests/, '/single_contest')
        ret = strip_contest_prefix(ret) unless strip_prefix == false
      end
      ret
    else
      polymorphic_path(records, options)
    end
  end

  def contest_adaptive_paginate(objects)
    if @layout == :single_contest
      html = paginate objects, params: { only_path: true }
      doc = Nokogiri::HTML::DocumentFragment.parse html
      doc.css('a').each do |el|
        el['href'] = strip_contest_prefix(el['href']) if el['href']
      end
      raw doc.to_s
    else
      paginate objects
    end
  end
end
