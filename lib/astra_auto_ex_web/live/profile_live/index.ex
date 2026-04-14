defmodule AstraAutoExWeb.ProfileLive.Index do
  use AstraAutoExWeb, :live_view

  alias AstraAutoEx.Accounts

  @providers [
    %{
      id: "ark",
      name: "ARK",
      desc: "Doubao, Seedream, Seedance",
      has_base_url: false,
      default_base_url: nil,
      models: %{
        "llm" => [
          %{id: "doubao-seed-1.6-pro", name: "Doubao Seed 1.6 Pro"},
          %{id: "doubao-seed-1.8", name: "Doubao Seed 1.8"},
          %{id: "doubao-seed-2.0-pro", name: "Doubao Seed 2.0 Pro"}
        ],
        "image" => [
          %{id: "doubao-seedream-4-0", name: "Seedream 4.0"},
          %{id: "doubao-seedream-4-5", name: "Seedream 4.5"},
          %{id: "doubao-seedream-5-0-lite", name: "Seedream 5.0 Lite"}
        ],
        "video" => [
          %{id: "doubao-seedance-1-0-pro-fast", name: "Seedance 1.0 Pro Fast"},
          %{id: "doubao-seedance-1-5-pro", name: "Seedance 1.5 Pro"},
          %{id: "doubao-seedance-2-0", name: "Seedance 2.0"}
        ]
      }
    },
    %{
      id: "google",
      name: "Google",
      desc: "Gemini, Imagen, VEO",
      has_base_url: false,
      default_base_url: nil,
      models: %{
        "llm" => [
          %{id: "gemini-2.5-flash", name: "Gemini 2.5 Flash"},
          %{id: "gemini-2.5-pro", name: "Gemini 2.5 Pro"},
          %{id: "gemini-3-flash", name: "Gemini 3 Flash"},
          %{id: "gemini-3.1-pro-preview", name: "Gemini 3.1 Pro"}
        ],
        "image" => [
          %{id: "imagen-4.0-generate-001", name: "Imagen 4"},
          %{id: "nano-banana-pro", name: "Nano Banana Pro"},
          %{id: "nano-banana-2", name: "Nano Banana 2"}
        ],
        "video" => [
          %{id: "veo-2.0-generate-001", name: "Veo 2.0"},
          %{id: "veo-3.0-generate-preview", name: "Veo 3.0"},
          %{id: "veo-3.1-generate-preview", name: "Veo 3.1"}
        ]
      }
    },
    %{
      id: "minimax",
      name: "MiniMax",
      desc: "Hailuo, TTS, Music",
      has_base_url: true,
      default_base_url: "https://api.minimaxi.com/v1",
      models: %{
        "llm" => [%{id: "m2.7-highspeed", name: "M2.7 Highspeed"}],
        "image" => [%{id: "image-01", name: "Image-01"}],
        "video" => [
          %{id: "minimax-hailuo-2.3", name: "Hailuo 2.3"},
          %{id: "minimax-hailuo-2.3-fast", name: "Hailuo 2.3 Fast"}
        ],
        "audio" => [
          %{id: "speech-2.8-hd", name: "Speech 2.8 HD"},
          %{id: "speech-2.8-turbo", name: "Speech 2.8 Turbo"}
        ],
        "music" => [%{id: "music-2.6", name: "Music 2.6"}]
      }
    },
    %{
      id: "fal",
      name: "FAL",
      desc: "Flux, Kling, Wan",
      has_base_url: false,
      default_base_url: nil,
      models: %{
        "image" => [
          %{id: "banana-pro", name: "Banana Pro"},
          %{id: "banana-2", name: "Banana 2"}
        ],
        "video" => [
          %{id: "fal-wan25", name: "Wan 2.6"},
          %{id: "fal-veo31", name: "Veo 3.1"},
          %{id: "fal-sora2", name: "Sora 2"},
          %{id: "fal-kling25-turbo-pro", name: "Kling 2.5 Turbo Pro"},
          %{id: "fal-kling3", name: "Kling 3"}
        ],
        "audio" => [%{id: "indextts-2", name: "IndexTTS 2"}],
        "lipsync" => [%{id: "kling-lip-sync", name: "Kling Lip Sync"}]
      }
    },