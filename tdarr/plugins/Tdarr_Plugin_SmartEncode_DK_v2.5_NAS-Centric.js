const details = () => ({
  id: "Tdarr_Plugin_SmartEncode_DK_v2.5_NAS-Centric",
  Stage: "Pre-processing",
  Name: "🚀 SmartEncode DK v2.5 (NAS-Centric Edition)",
  Type: "Video",
  Operation: "Transcode",
  Description: "Tailored for CPU encoding (7950X) towards a NAS (Synology). Removes all unnecessary elements and focuses on H.264 quality, advanced audio/subtitle control, and optional, intelligent fine-tuning of content.",
  Version: "2.5",
  Tags: "pre-processing,ffmpeg,cpu,h264,nas,synology,smart-tuning",
  Inputs: [
    {
      name: "base_crf",
      type: "string",
      defaultValue: "22",
      inputUI: { type: "text" },
      tooltip: "Set your base quality level (CRF). 18-24 is typical. Lower = better quality and larger file."
    },
    {
      name: "enable_smart_tuning",
      type: "boolean",
      defaultValue: true,
      inputUI: {
        type: "dropdown",
        options: ["true", "false"]
      },
      tooltip: "TRUE: Adds fine-tuning (-tune animation/grain) based on content. FALSE: Uses only '-tune film' for everything."
    },
    {
      name: "keep_subtitles",
      type: "boolean",
      defaultValue: false,
      inputUI: {
        type: "dropdown",
        options: ["true", "false"]
      },
      tooltip: "Select 'true' to keep all subtitle tracks. 'false' removes them."
    },
    {
      name: "force_1080p",
      type: "boolean",
      defaultValue: true,
      inputUI: {
        type: "dropdown",
        options: ["true", "false"]
      },
      tooltip: "Downscale 4K to 1080p to save space and network bandwidth on your NAS."
    },
    {
      name: "skip_small_files_mb",
      type: "string",
      defaultValue: "100",
      inputUI: { type: "text" },
      tooltip: "Skip files under X MB to reduce network traffic. Set to 0 to process all."
    },
    {
      name: "thread_count",
      type: "string",
      defaultValue: "0",
      inputUI: { type: "text" },
      tooltip: "Number of CPU threads (0 = auto-detect based on file size for optimal performance on your 7950X)."
    }
  ]
});

const plugin = (file, librarySettings, inputs, otherArguments) => {
  const lib = require("../methods/lib")();
  inputs = lib.loadDefaultValues(inputs, details);

  const response = {
    processFile: false,
    preset: "",
    container: ".mp4",
    handBrakeMode: false,
    FFmpegMode: true,
    reQueueAfter: false,
    infoLog: "🚀 SmartEncode DK v2.5 (NAS-Centric Edition)\n\n"
  };

  if (!file.ffProbeData || !file.ffProbeData.streams) {
    response.infoLog += "❌ Corrupt file or missing data. Aborting.\n";
    return response;
  }

  const videoStream = file.ffProbeData.streams.find(s => s.codec_type === "video");
  if (!videoStream) {
    response.infoLog += "❌ No video stream found. Aborting.\n";
    return response;
  }

  const audioStreams = file.ffProbeData.streams.filter(s => s.codec_type === "audio");
  const subtitleStreams = file.ffProbeData.streams.filter(s => s.codec_type === "subtitle");

  // NAS-friendly checks (from v2.3)
  const fileSizeMB = file.file_size / (1024 * 1024);
  const skipThreshold = parseInt(inputs.skip_small_files_mb) || 100;
  const duration = parseFloat(file.ffProbeData.format?.duration || 0);

  if (skipThreshold > 0 && fileSizeMB < skipThreshold) {
    response.infoLog += `⚡ Skipping small file (${Math.round(fileSizeMB)}MB < ${skipThreshold}MB) to save network.\n`;
    return response;
  }
  if (duration < 60) {
    response.infoLog += "⏱️ Skipping short video (<1 minute).\n";
    return response;
  }

  // Flexible "Perfect File" check (adapted from v2.3)
  const isFilePerfect = () => {
    const hasCorrectVideo = videoStream.codec_name === 'h264';
    const hasCorrectContainer = file.container === 'mp4';
    const subtitlesAreCorrect = inputs.keep_subtitles === 'true' || subtitleStreams.length === 0;
    const hasAc3 = audioStreams.some(s => s.codec_name === 'ac3');
    const hasAac = audioStreams.some(s => s.codec_name === 'aac');
    const hasCorrectAudio = hasAc3 && hasAac;

    if (hasCorrectVideo && hasCorrectContainer && subtitlesAreCorrect && hasCorrectAudio) {
      return true;
    }
    return false;
  };

  if (isFilePerfect()) {
    response.infoLog += `☑️ File is already perfect (MP4/H264, correct audio/subs). Skipping.\n`;
    return response;
  }

  // Smart-Tuning (The Surprise!)
  let tuneSetting = '-tune film';
  if (inputs.enable_smart_tuning === 'true') {
    const filename = (file.file || "").toLowerCase();
    const isAnimation = filename.match(/\b(anime|animation|animated|cartoon|pixar|dreamworks|disney|ghibli|studio)\b/i);
    const isClassic = (file.meta?.year && file.meta.year < 2000) || filename.match(/\b(classic|criterion|restored|remastered|noir|western|35mm|grain|vintage|bw|black.?white)\b/i);

    if (isAnimation) {
      tuneSetting = '-tune animation';
      response.infoLog += '🎨 Smart-Tuning: Animation detected. Using "-tune animation".\n';
    } else if (isClassic) {
      tuneSetting = '-tune grain';
      response.infoLog += '🎞️ Smart-Tuning: Classic/grainy film detected. Using "-tune grain".\n';
    } else {
        response.infoLog += '🎬 Smart-Tuning: Standard film detected. Using "-tune film".\n';
    }
  }

  // CPU & Encoder Setup
  let threads = parseInt(inputs.thread_count) || 0;
  if (threads === 0) {
    threads = Math.min(16, Math.max(4, Math.floor(fileSizeMB / 500)));
  }

  let cpuPreset = "medium";
  if (fileSizeMB > 4000) cpuPreset = "faster";
  else if (fileSizeMB > 1000) cpuPreset = "fast";
  
  const videoEncoderArgs = `-c:v libx264 -preset ${cpuPreset} ${tuneSetting} -crf ${inputs.base_crf} -profile:v high -level 4.1 -threads ${threads}`;

  // Scaling
  const is4K = videoStream.width > 1920;
  const force1080p = inputs.force_1080p === "true";
  let scaleFilter = "";
  if (force1080p && is4K) {
    scaleFilter = "-vf scale=1920:-2:flags=lanczos ";
  }

  // Advanced Audio & Subtitle handling (from v2.3)
  const audioLangs = ["da", "dan", "dansk", "en", "eng", "english", "und"];
  let selectedAudio = audioStreams.filter(a => audioLangs.includes((a.tags?.language || "und").toLowerCase()));
  if (selectedAudio.length === 0 && audioStreams.length > 0) selectedAudio = [audioStreams[0]];

  let audioMaps = "", audioCodecs = "";
  selectedAudio.forEach((audio, i) => {
    const streamIndex = audioStreams.indexOf(audio);
    const channels = audio.channels || 2;
    const outStreamBase = i * 2;
    audioMaps += ` -map 0:a:${streamIndex} -map 0:a:${streamIndex}`;

    if (channels > 2) {
      const bitrate = channels >= 6 ? "448k" : "384k";
      audioCodecs += ` -c:a:${outStreamBase} ac3 -b:a:${outStreamBase} ${bitrate} -ac:a:${outStreamBase} 6`;
    } else {
      audioCodecs += ` -c:a:${outStreamBase} copy`;
    }
    audioCodecs += ` -c:a:${outStreamBase + 1} aac -b:a:${outStreamBase + 1} 160k -ac:a:${outStreamBase + 1} 2`;
  });
  
  let subtitleMap = "";
  if (inputs.keep_subtitles === 'true' && subtitleStreams.length > 0) {
    subtitleMap = " -map 0:s? -c:s copy";
  }

  // Assemble the final command
  response.preset = `, -map 0:v${audioMaps}${subtitleMap} ${scaleFilter}-pix_fmt yuv420p ${videoEncoderArgs}${audioCodecs} -movflags +faststart`;
  response.processFile = true;

  // Detailed Summary
  response.infoLog += `\n✅ Ready for CPU encoding!\n`;
  response.infoLog += `├─ Quality: CRF ${inputs.base_crf}\n`;
  response.infoLog += `├─ Smart-Tuning: ${inputs.enable_smart_tuning === 'true' ? tuneSetting : 'Disabled'}\n`;
  response.infoLog += `├─ CPU Optimization: Preset '${cpuPreset}' with ${threads} threads\n`;
  response.infoLog += `├─ Audio: ${selectedAudio.length}x2 tracks (AC3/AAC) from DA/EN sources\n`;
  response.infoLog += `└─ Subtitles: ${inputs.keep_subtitles === 'true' ? 'Kept' : 'Removed'}\n`;

  return response;
};

module.exports.details = details;
module.exports.plugin = plugin;