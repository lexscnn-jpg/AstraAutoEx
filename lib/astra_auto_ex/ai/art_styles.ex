defmodule AstraAutoEx.AI.ArtStyles do
  @moduledoc """
  17 preset art styles + 1 custom, each with bilingual prompts.
  Ported from original AstraAuto constants.ts.
  """

  @presets [
    %{
      value: "realistic",
      label_zh: "真人写实",
      label_en: "Realistic",
      preview: "实",
      category: "写实/电影",
      prompt_zh: "超写实真人实拍风格，高清细腻的皮肤纹理、自然光影、真实的面部特征和表情。电影级色彩校正，4K质感。",
      prompt_en: "Ultra-realistic live-action style with high-definition skin texture, natural lighting and shadows, authentic facial features and expressions. Cinematic color grading, 4K quality."
    },
    %{
      value: "cinematic-film",
      label_zh: "电影胶片",
      label_en: "Cinematic Film",
      preview: "影",
      category: "写实/电影",
      prompt_zh: "35mm电影胶片美学，自然胶片颗粒感、浅景深、黄金时段暖色调。宽银幕构图，真实质感光影。",
      prompt_en: "35mm film aesthetic with natural grain, shallow depth of field, golden hour warm tones. Widescreen composition, authentic texture and lighting."
    },
    %{
      value: "japanese-anime",
      label_zh: "日系动漫",
      label_en: "Japanese Anime",
      preview: "日",
      category: "动漫/漫画",
      prompt_zh: "日系赛璐璐动漫风格，干净的线条、鲜明的色块、大眼角色设计。动态构图，专业动画级光影效果。",
      prompt_en: "Japanese cel-shaded anime style with clean lines, vivid color blocks, large-eye character design. Dynamic composition, professional animation-grade lighting."
    },
    %{
      value: "chinese-comic",
      label_zh: "精致国漫",
      label_en: "Chinese Comic",
      preview: "国",
      category: "动漫/漫画",
      prompt_zh: "精致国漫风格，3D转2D渲染质感、华丽的色彩、细腻的光影层次。融合东方美学元素。",
      prompt_en: "Premium Chinese comic style with 3D-to-2D rendering quality, gorgeous colors, delicate lighting layers. Fused with Eastern aesthetic elements."
    },
    %{
      value: "3d-animation",
      label_zh: "3D动画",
      label_en: "3D Animation",
      preview: "3D",
      category: "3D/动画",
      prompt_zh: "高品质3D动画风格，皮克斯/迪士尼级渲染质感、柔和的光照、圆润的角色设计。丰富的材质细节。",
      prompt_en: "High-quality 3D animation style, Pixar/Disney-level rendering, soft lighting, rounded character design. Rich material details."
    },
    %{
      value: "film-noir",
      label_zh: "黑色电影",
      label_en: "Film Noir",
      preview: "黑",
      category: "氛围/风格化",
      prompt_zh: "黑色电影风格，高对比度黑白画面、戏剧性阴影、硬光轮廓。雨天街道、百叶窗光影、犯罪美学。",
      prompt_en: "Film noir style with high-contrast black and white imagery, dramatic shadows, hard-light silhouettes. Rainy streets, venetian blind shadows, crime aesthetics."
    },
    %{
      value: "cyberpunk",
      label_zh: "赛博朋克",
      label_en: "Cyberpunk",
      preview: "赛",
      category: "氛围/风格化",
      prompt_zh: "赛博朋克风格，霓虹灯光、未来都市景观、科技感界面。青紫色调、雨中反射、赛博增强人体。",
      prompt_en: "Cyberpunk style with neon lighting, futuristic cityscape, tech-infused interfaces. Cyan-purple tones, rain reflections, cyber-augmented bodies."
    },
    %{
      value: "ink-wash",
      label_zh: "水墨国风",
      label_en: "Ink Wash",
      preview: "墨",
      category: "氛围/风格化",
      prompt_zh: "传统水墨画风格，留白意境、墨色浓淡变化、山水写意。东方禅意美学，泼墨渲染。",
      prompt_en: "Traditional Chinese ink painting style with intentional white space, ink gradations, freehand landscape. Eastern Zen aesthetics, splashed ink rendering."
    },
    %{
      value: "retro-vintage",
      label_zh: "复古怀旧",
      label_en: "Retro Vintage",
      preview: "旧",
      category: "氛围/风格化",
      prompt_zh: "VHS复古风格，Lo-Fi怀旧质感、褪色胶片色调、扫描线纹理。80-90年代影像美学。",
      prompt_en: "VHS retro style, Lo-Fi nostalgic texture, faded film tones, scan line textures. 80s-90s visual aesthetics."
    },
    %{
      value: "macro-cinematography",
      label_zh: "微距摄影",
      label_en: "Macro Cinematography",
      preview: "微",
      category: "特殊类型",
      prompt_zh: "微距摄影风格，极致细节特写、超浅景深、微观世界的宏大叙事。水珠、纹理、昆虫翅膀般的精细度。",
      prompt_en: "Macro cinematography with extreme close-up detail, ultra-shallow depth of field, grand narrative of the microscopic world."
    },
    %{
      value: "epic-sci-fi",
      label_zh: "科幻史诗",
      label_en: "Epic Sci-Fi",
      preview: "科",
      category: "特殊类型",
      prompt_zh: "科幻史诗风格，太空歌剧级视觉、体积光渲染、宏大的宇宙场景。金属质感、全息界面、星际文明。",
      prompt_en: "Epic sci-fi style, space opera visuals, volumetric lighting, grand cosmic scenes. Metallic textures, holographic interfaces, interstellar civilization."
    },
    %{
      value: "clay-stop-motion",
      label_zh: "黏土定格",
      label_en: "Clay Stop Motion",
      preview: "黏",
      category: "特殊类型",
      prompt_zh: "黏土定格动画风格，手工质感、微缩模型场景、可爱圆润的角色造型。指纹肌理、温暖光照。",
      prompt_en: "Clay stop-motion animation with handcrafted texture, miniature model scenes, cute rounded character designs. Fingerprint texture, warm lighting."
    },
    %{
      value: "dark-fantasy",
      label_zh: "黑暗奇幻",
      label_en: "Dark Fantasy",
      preview: "暗",
      category: "特殊类型",
      prompt_zh: "黑暗奇幻风格，哥特式建筑、戏剧性阴影、神秘魔法光效。暗色调为主、细节华丽的盔甲与法杖。",
      prompt_en: "Dark fantasy style with Gothic architecture, dramatic shadows, mystical magical lighting. Dark tones, ornate armor and staffs."
    },
    %{
      value: "documentary-style",
      label_zh: "纪实风格",
      label_en: "Documentary Style",
      preview: "纪",
      category: "特殊类型",
      prompt_zh: "纪实摄影风格，真实原始的画面质感、自然抓拍构图、新闻摄影美学。不加修饰的真实感。",
      prompt_en: "Documentary photography style with raw authentic visuals, candid compositions, photojournalistic aesthetics. Unretouched realism."
    },
    %{
      value: "product-commercial",
      label_zh: "商业广告",
      label_en: "Product Commercial",
      preview: "商",
      category: "特殊类型",
      prompt_zh: "高端商业广告风格，产品摄影级光照、干净的背景、精致的材质渲染。杂志级构图和色彩。",
      prompt_en: "Premium product commercial style with studio-grade lighting, clean backgrounds, refined material rendering. Magazine-quality composition and color."
    },
    %{
      value: "surreal-dream",
      label_zh: "超现实主义",
      label_en: "Surreal Dream",
      preview: "梦",
      category: "特殊类型",
      prompt_zh: "超现实主义风格，达利式梦境构图、扭曲的时空、荒诞却精致的视觉。融化的时钟、漂浮物体。",
      prompt_en: "Surrealist style with Dalí-inspired dreamscape composition, warped spacetime, absurd yet refined visuals. Melting clocks, floating objects."
    },
    %{
      value: "premium-live-action-xianxia",
      label_zh: "纯净史诗仙侠实拍",
      label_en: "Premium Xianxia",
      preview: "仙",
      category: "特殊类型",
      prompt_zh: "高端仙侠实拍风格，飘逸的仙气、云雾缭绕的仙山、精致的古装造型。空灵的色调、光芒四射的法力特效。",
      prompt_en: "Premium live-action xianxia style with ethereal fairy aura, misty immortal mountains, exquisite period costumes. Ethereal tones, radiant magical effects."
    },
    %{
      value: "custom",
      label_zh: "自定义",
      label_en: "Custom",
      preview: "✎",
      category: "用户自定义",
      prompt_zh: "",
      prompt_en: ""
    }
  ]

  @legacy_map %{
    "american-comic" => "japanese-anime",
    "anime" => "japanese-anime",
    "oil_painting" => "cinematic-film"
  }

  @doc "List all art style presets."
  def list_presets, do: @presets

  @doc "Get a single preset by value."
  def get_preset(value) do
    resolved = Map.get(@legacy_map, value, value)
    Enum.find(@presets, fn p -> p.value == resolved end)
  end

  @doc "Get the prompt suffix for a style in the given locale."
  def get_prompt(value, locale \\ "zh", custom_prompt \\ nil) do
    case value do
      "custom" ->
        custom_prompt || ""

      _ ->
        case get_preset(value) do
          nil -> ""
          preset -> if locale == "en", do: preset.prompt_en, else: preset.prompt_zh
        end
    end
  end

  @doc "Check if a value is a valid art style."
  def valid?(value), do: Enum.any?(@presets, fn p -> p.value == value end) or Map.has_key?(@legacy_map, value)
end
