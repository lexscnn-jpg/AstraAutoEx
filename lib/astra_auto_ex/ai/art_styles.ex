defmodule AstraAutoEx.AI.ArtStyles do
  @moduledoc """
  17 predefined art styles + custom option.
  Each style has Chinese and English prompt text.
  """

  @styles [
    %{value: "realistic", label: "写实", label_en: "Realistic",
      prompt_zh: "超写实真人实拍画面。极致面部细节，自然皮肤纹理清晰可见，8K分辨率，电影级布光",
      prompt_en: "Photorealistic live-action footage with extreme facial detail, natural skin texture, 8K resolution, cinematic lighting"},
    %{value: "cinematic-film", label: "电影胶片", label_en: "Cinematic Film",
      prompt_zh: "35mm胶片质感，变形宽银幕镜头，电影级调色，温暖色调，浅景深，颗粒感",
      prompt_en: "35mm film grain, anamorphic lenses, cinematic color grading, warm tones, shallow depth of field"},
    %{value: "japanese-anime", label: "日系动漫", label_en: "Japanese Anime",
      prompt_zh: "日式赛璐璐上色风格，饱和明亮色彩，吉卜力式氛围感，精致线条",
      prompt_en: "Japanese cel-shading style, saturated bright colors, Ghibli-style atmospheric feel, refined linework"},
    %{value: "chinese-comic", label: "精致国漫", label_en: "Chinese Comic",
      prompt_zh: "3D转2D渲染风格，粒子特效，东方美学元素，精致画面",
      prompt_en: "3D-to-2D rendering style, particle effects, Eastern aesthetics, refined visuals"},
    %{value: "3d-animation", label: "3D动画", label_en: "3D Animation",
      prompt_zh: "皮克斯/迪士尼风格3D渲染，柔和光照，卡通质感，精致材质",
      prompt_en: "Pixar/Disney style 3D rendering, soft lighting, cartoon texture, refined materials"},
    %{value: "film-noir", label: "黑色电影", label_en: "Film Noir",
      prompt_zh: "高对比度黑白画面，硬光阴影，侦探悬疑氛围，经典好莱坞",
      prompt_en: "High contrast black and white, hard shadow lighting, detective noir atmosphere"},
    %{value: "cyberpunk", label: "赛博朋克", label_en: "Cyberpunk",
      prompt_zh: "霓虹灯光，雨夜都市，未来科技感，紫蓝色调，全息投影",
      prompt_en: "Neon lights, rainy urban nights, futuristic tech, purple-blue tones, holographic projections"},
    %{value: "ink-wash", label: "水墨画", label_en: "Ink Wash",
      prompt_zh: "中国传统水墨画风格，留白意境，淡雅墨色，山水写意",
      prompt_en: "Traditional Chinese ink wash painting, white space aesthetics, subtle ink tones, landscape freehand"},
    %{value: "retro-vintage", label: "复古怀旧", label_en: "Retro Vintage",
      prompt_zh: "70年代复古色调，褪色胶片效果，暖黄色调，怀旧滤镜",
      prompt_en: "70s retro color tones, faded film effect, warm yellow tones, nostalgic filter"},
    %{value: "macro-cinema", label: "微距电影", label_en: "Macro Cinema",
      prompt_zh: "极致微距镜头，超浅景深，细节放大，电影级微观世界",
      prompt_en: "Extreme macro lens, ultra-shallow depth of field, magnified details, cinematic micro world"},
    %{value: "epic-scifi", label: "史诗科幻", label_en: "Epic Sci-Fi",
      prompt_zh: "宏大太空场景，未来城市，星际战舰，宇宙级视觉奇观",
      prompt_en: "Grand space scenes, future cities, interstellar warships, cosmic visual spectacle"},
    %{value: "clay-stopmotion", label: "粘土定格", label_en: "Clay Stop-Motion",
      prompt_zh: "粘土定格动画质感，手工制作感，温暖色调，微缩场景",
      prompt_en: "Clay stop-motion animation texture, handmade feel, warm tones, miniature scenes"},
    %{value: "dark-fantasy", label: "暗黑奇幻", label_en: "Dark Fantasy",
      prompt_zh: "哥特式暗黑风格，魔幻元素，深色调，神秘氛围",
      prompt_en: "Gothic dark style, magical elements, deep tones, mysterious atmosphere"},
    %{value: "documentary", label: "纪录片", label_en: "Documentary",
      prompt_zh: "真实纪录片风格，自然光，手持镜头感，真实质朴",
      prompt_en: "Real documentary style, natural light, handheld camera feel, authentic and raw"},
    %{value: "product-ad", label: "产品广告", label_en: "Product Ad",
      prompt_zh: "商业广告级画面，完美布光，产品特写，高端质感",
      prompt_en: "Commercial ad quality, perfect lighting, product close-up, premium texture"},
    %{value: "surreal-dream", label: "超现实梦境", label_en: "Surreal Dream",
      prompt_zh: "超现实主义画面，梦境般的场景，扭曲透视，奇幻色彩",
      prompt_en: "Surrealist visuals, dreamlike scenes, distorted perspective, fantastical colors"},
    %{value: "xianxia", label: "仙侠古风", label_en: "Xianxia",
      prompt_zh: "东方仙侠风格，仙气飘飘，古典建筑，云雾缭绕，真人实拍质感",
      prompt_en: "Eastern xianxia style, ethereal atmosphere, classical architecture, misty clouds, live-action quality"}
  ]

  @custom_value "custom"

  def all_styles, do: @styles

  def style_options do
    Enum.map(@styles, &{&1.label, &1.value}) ++ [{"自定义", @custom_value}]
  end

  def get_prompt(nil, _locale), do: ""
  def get_prompt("", _locale), do: ""

  def get_prompt(@custom_value, _locale), do: ""

  def get_prompt(style_value, locale \\ "zh") do
    case Enum.find(@styles, &(&1.value == style_value)) do
      nil -> ""
      style -> if locale == "en", do: style.prompt_en, else: style.prompt_zh
    end
  end

  def get_label(nil), do: ""

  def get_label(style_value) do
    case Enum.find(@styles, &(&1.value == style_value)) do
      nil -> if style_value == @custom_value, do: "自定义", else: style_value
      style -> style.label
    end
  end

  def custom_value, do: @custom_value
end
