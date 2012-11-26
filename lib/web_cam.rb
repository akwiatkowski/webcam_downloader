class WebCam
  def initialize(_options)
    @options = _options
    @desc = _options[:desc]
  end
  
  attr_reader :desc
end