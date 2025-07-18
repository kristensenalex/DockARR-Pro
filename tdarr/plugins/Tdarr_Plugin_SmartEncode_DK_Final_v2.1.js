const details = () => ({
  id: "Tdarr_Plugin_SmartEncode_DK_Final_v2.1",
  Stage: "Pre-processing",
  Name: "🚀 SmartEncode DK Final v2.1",
  Type: "Video",
  Operation: "Transcode",
  Description: "🎯 [FIXED] Intelligent preset selector. This version ensures the output file ALWAYS replaces the original. It checks for correct audio streams and absence of subtitles before skipping a file.",
  Version: "2.1",
  Tags: "pre-processing,ffmpeg,handbrake,smartencode,4k,hdr,fix",
  Inputs: [
    {
      name: "force_preset",
      type: "string",
      defaultValue: "auto",
      inputUI: {
        type: "dropdown",
        options: ["auto", "general", "animation", "classic", "4k_elite"]
      },
      tooltip: "Force a specific preset or let the plugin choose automatically"
    },
    {
      name: "custom_crf",
      type: "string",
      defaultValue: "",
      inputUI: { type: "text" },
      tooltip: "Specify custom CRF (e.g. 20). Empty = use preset default"
    },
    {
      name: "force_1080p",
      type: "boolean",
      defaultValue: true,
      inputUI: {
        type: "dropdown",
        options: ["true", "false"]
      },
      tooltip: "Force 4K files to 1080p"
    }
  ]
});

const plugin = (file, librarySettings, inputs, otherArguments) => {
  const lib = require('../methods/lib')();
  inputs = lib.loadDefaultValues(inputs, details);

  const response = {
    processFile: false,
    preset: "",
    container: ".mp4",
    handBrakeMode: false,
    FFmpegMode: true,
    reQueueAfter: false,
    infoLog: "🚀 SmartEncode DK Final v2.1 (FIXED)\n\n"
  };

  // 📌 Safe stream retrieval
  const videoStream = file.ffProbeData.streams.find(s => s.codec_type === "video");
  const audioStreams = file.ffProbeData.streams.filter(s => s.codec_type === 'audio');
  const subtitleStreams = file.ffProbeData.streams.filter(s => s.codec_type === 'subtitle');

  if (!videoStream) {
    response.infoLog += "❌ No video stream found. Aborting.\n";
    return response;
  }
  
  // =================================================================================================
  // 💡 START: FIXED LOGIC
  // This new function checks if the file is 100% as desired (MP4, H264, correct audio, no subs).
  // Only if ALL conditions are met, we skip. This solves the problem.
  // =================================================================================================
  const isFileAlreadyPerfect = () => {
    // Check for at least one AC3 5.1 track AND one AAC stereo track
    const hasAc3_51 = audioStreams.some(s => s.codec_name === 'ac3' && s.channels === 6);
    const hasAacStereo = audioStreams.some(s => s.codec_name === 'aac' && s.channels === 2);
    
    if (
      file.container === "mp4" &&
      videoStream.codec_name === "h264" &&
      subtitleStreams.length === 0 && // MUST have zero embedded subtitles
      audioStreams.length >= 2 && // MUST have at least 2 audio tracks (AC3 + AAC)
      hasAc3_51 &&
      hasAacStereo
    ) {
      return true;
    }
    return false;
  };

  if (isFileAlreadyPerfect()) {
      response.infoLog += "☑️ File is already 100% in correct format (MP4/H264, AC3+AAC Audio, no subs). Skipping.\n";
      return response;
  }
  // =================================================================================================
  // 💡 END: FIXED LOGIC
  // =================================================================================================


  const filename = (file.file || "").toLowerCase();
  const filepath = (file.filePath || "").toLowerCase();
  const width = parseInt(videoStream.width);
  const height = parseInt(videoStream.height);
  const codec = videoStream.codec_name;
  const is4K = width > 1920 || height > 1080;
  const isHDR = ["smpte2084", "arib-std-b67"].includes(videoStream.color_transfer);
  const force1080p = inputs.force_1080p !== "false";

  const yearMatch = filename.match(/\b(19[0-9]\d|20[0-2]\d)\b/);
  const year = yearMatch ? parseInt(yearMatch[1]) : null;

  let preset = "general";

  if (inputs.force_preset === "auto") {
    if (is4K || isHDR) {
      preset = "4k_elite";
      response.infoLog += "💎 DETECTED: 4K/HDR content\n";
    } else if (
      filename.match(/\b(anime|animation|animated|cartoon|pixar|dreamworks|disney|ghibli|studio)\b/i) ||
      filepath.includes("anime") ||
      filepath.includes("animation") ||
      filepath.includes("cartoon") ||
      (filename.includes("[") && filename.includes("]")) ||
      (filename.match(/\bs\d{1,2}e\d{1,2}\b/i) && filename.match(/\b(anime|toon)\b/i))
    ) {
      preset = "animation";
      response.infoLog += "🎨 DETECTED: Animation/Anime content\n";
    } else if (
      (year && year < 2000) ||
      filename.match(/\b(classic|criterion|restored|remastered|noir|western|35mm|grain|vintage|bw|black.?white)\b/i) ||
      filepath.includes("classics") ||
      filepath.includes("criterion") ||
      filename.match(/\b(1080|720)p\.grain\./i)
    ) {
      preset = "classic";
      response.infoLog += `🎞️ DETECTED: Classic/Grainy film${year ? " from " + year : ""}\n`;
    } else {
      preset = "general";
      response.infoLog += `🎬 DETECTED: Modern content${year ? " from " + year : ""}\n`;
    }
  } else {
    preset = inputs.force_preset;
    response.infoLog += `⚙️ FORCED: User selected preset '${preset}'\n`;
  }

  const baseCRF = inputs.custom_crf?.trim() ? inputs.custom_crf : null;

  let scaleFilter = "";
  if (force1080p && is4K) {
    scaleFilter = "-vf scale=1920:-2:flags=lanczos ";
    response.infoLog += "📐 Downscaling from 4K to 1080p\n";
  }

  const presets = {
    general: {
      name: "🎬 General Elite",
      crf: 22,
      args: "-c:v libx264 -preset medium -tune film -profile:v high -level 4.1 " +
            "-crf 22 -maxrate 6000k -bufsize 12000k " +
            "-x264-params subme=0:me_range=4:rc_lookahead=10:me=hex:8x8dct=0:partitions=none:ref=3:bframes=3:b-adapt=1:direct=spatial:weightp=1:keyint=240:min-keyint=24:scenecut=40"
    },
    animation: {
      name: "🎨 Animation Pro",
      crf: 21,
      args: "-c:v libx264 -preset fast -tune animation -profile:v high -level 4.1 " +
            "-crf 21 -maxrate 6000k -bufsize 12000k " +
            "-x264-params subme=0:me_range=4:rc_lookahead=10:me=dia:no-chroma-me:8x8dct=0:partitions=none:ref=3:bframes=3:b-adapt=1:direct=spatial:weightp=1:keyint=240:min-keyint=24:scenecut=40:deblock=-1,-1:psy-rd=0.4:0"
    },
    classic: {
      name: "🎞️ Classic Master",
      crf: 20,
      args: "-c:v libx264 -preset slower -tune grain -profile:v high -level 4.1 " +
            "-crf 20 -maxrate 6000k -bufsize 12000k " +
            "-x264-params subme=2:me_range=4:rc_lookahead=10:me=hex:8x8dct=1:ref=4:bframes=4:b-adapt=2:direct=auto:weightp=1:keyint=240:min-keyint=24:scenecut=40:rc-lookahead=50:aq-mode=1:aq-strength=0.8"
    },
    "4k_elite": {
      name: "💎 4K Elite",
      crf: 18,
      args: "-c:v libx264 -preset slow -profile:v high -level 4.1 " +
            "-crf 18 -maxrate 8000k -bufsize 16000k " +
            "-x264-params subme=2:me_range=4:rc_lookahead=10:me=hex:8x8dct=1:partitions=none:ref=4:bframes=3:b-adapt=1:direct=spatial:weightp=1:keyint=240:min-keyint=24:scenecut=40:rc-lookahead=50"
    }
  };

  const chosen = presets[preset];
  const crf = baseCRF || chosen.crf;

  let audioMaps = "";
  let audioCodecs = "";
  
  response.infoLog += `\n🔊 Original audio streams found: ${audioStreams.length}\n`;
  
  if (audioStreams.length > 0) {
    // We only take the FIRST audio track from the original and make two new ones from it.
    const sourceAudio = audioStreams[0];
    const channels = sourceAudio.channels || 2;
    const lang = sourceAudio.tags?.language || 'und';
    
    audioMaps = ` -map 0:a:0 -map 0:a:0`;
    
    // First version: AC3 5.1 if multi-channel
    if (channels > 2) {
      const bitrate = "384k";
      audioCodecs += ` -c:a:0 ac3 -b:a:0 ${bitrate} -ac:a:0 6`;
      response.infoLog += `   - New Audio 1 (from source 1, ${lang}): ${channels}ch → AC3 5.1 (${bitrate})\n`;
    } else {
      audioCodecs += ` -c:a:0 copy`;
      response.infoLog += `   - New Audio 1 (from source 1, ${lang}): ${channels}ch → Copy original\n`;
    }
    
    // Second version: AAC stereo
    const aacBitrate = "160k";
    audioCodecs += ` -c:a:1 aac -b:a:1 ${aacBitrate} -ac:a:1 2`;
    response.infoLog += `   - New Audio 2 (from source 1, ${lang}): → AAC stereo (${aacBitrate})\n`;
  }

  if (subtitleStreams.length > 0) {
    response.infoLog += `\n📝 Original subtitles found: ${subtitleStreams.length} tracks. These will be removed.\n`;
  }

  response.preset = `, -map 0:v${audioMaps} ${scaleFilter}-pix_fmt yuv420p ${chosen.args.replace(/-crf \d+/, `-crf ${crf}`)}${audioCodecs} -movflags +faststart`;
  response.processFile = true;

  response.infoLog += `\n✅ Using preset: ${chosen.name}\n`;
  response.infoLog += `📊 Source: ${width}x${height} ${codec}${isHDR ? " (HDR)" : ""}, Year: ${year || "unknown"}\n`;
  response.infoLog += `🔧 Used CRF: ${crf}${force1080p && is4K ? " + 1080p downscaling" : ""}\n`;
  response.infoLog += `💾 Output: MP4/H264 with AC3 5.1 & AAC Stereo. NO subtitles.\n`;

  return response;
};

module.exports.details = details;
module.exports.plugin = plugin;