const details = () => ({
  id: "Tdarr_Plugin_SmartEncode_DK_v3.0_Titan-Edition",
  Stage: "Pre-processing",
  Name: "🚀 SmartEncode DK v3.0 (Titan Edition)",
  Type: "Video",
  Operation: "Transcode",
  Description: "Future-proof version for high-end systems. Full control over CPU/GPU, H.264/H.265/AV1 codecs, and retains the intelligent NAS-optimized engine.",
  Version: "3.0",
  Tags: "h265,av1,h264,gpu,cpu,amd,amf,7900xtx,future-proof",
  Inputs: [
    {
      name: "target_codec",
      type: "string",
      defaultValue: "h265",
      inputUI: {
        type: "dropdown",
        options: ["h264", "h265", "av1"]
      },
      tooltip: "Select your target codec. H.265 is the modern standard. AV1 is the future (requires powerful hardware)."
    },
    {
      name: "encoder_type",
      type: "string",
      defaultValue: "cpu",
      inputUI: {
        type: "dropdown",
        options: ["cpu", "gpu_amd"]
      },
      tooltip: "Choose your encoder. CPU for maximum quality. GPU for maximum speed."
    },
    {
      name: "quality_level",
      type: "string",
      defaultValue: "22",
      inputUI: { type: "text" },
      tooltip: "Quality level. CPU (CRF): 18-24. GPU (QP): 20-28. AV1 (CRF): 25-35. Lower = better."
    },
    {
        name: "cpu_speed_preset",
        type: "string",
        defaultValue: "medium",
        inputUI: {
          type: "dropdown",
          options: ["slower", "slow", "medium", "fast", "faster"]
        },
        tooltip: "CPU only. Sets a balance between encoding time and efficiency. 'medium' is a good starting point."
    },
    {
      name: "enable_smart_tuning",
      type: "boolean",
      defaultValue: true,
      inputUI: {
        type: "dropdown",
        options: ["true", "false"]
      },
      tooltip: "Adds '-tune' optimizations based on content (only for H.264/H.265)."
    },
    {
      name: "keep_subtitles",
      type: "boolean",
      defaultValue: true,
      inputUI: {
        type: "dropdown",
        options: ["true", "false"]
      },
      tooltip: "Select 'true' to keep all subtitle tracks."
    },
    {
      name: "force_1080p",
      type: "boolean",
      defaultValue: false,
      inputUI: {
        type: "dropdown",
        options: ["true", "false"]
      },
      tooltip: "Downscale 4K content to 1080p. Recommended 'false' for a high-end setup."
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
    infoLog: "🚀 SmartEncode DK v3.0 (Titan Edition)\n\n"
  };

  if (!file.ffProbeData?.streams) {
    response.infoLog += "❌ Corrupt file or missing data. Aborting.\n";
    return response;
  }
  
  const videoStream = file.ffProbeData.streams.find(s => s.codec_type === "video");
  if (!videoStream) {
    response.infoLog += "❌ No video stream found. Aborting.\n";
    return response;
  }

  // Perfect File Check - now with full codec support
  const isFilePerfect = () => {
    let targetCodecName = '';
    if (inputs.target_codec === 'h265') targetCodecName = 'hevc';
    else if (inputs.target_codec === 'av1') targetCodecName = 'av1';
    else targetCodecName = 'h264';
    
    const hasCorrectVideo = videoStream.codec_name === targetCodecName;
    const hasCorrectContainer = file.container === 'mp4';
    const subtitlesAreCorrect = inputs.keep_subtitles === 'true' || file.ffProbeData.streams.filter(s => s.codec_type === 'subtitle').length === 0;
    
    // Simple audio check, as full handling is heavy
    const hasAc3 = file.ffProbeData.streams.some(s => s.codec_name === 'ac3');
    const hasAac = file.ffProbeData.streams.some(s => s.codec_name === 'aac');

    if (hasCorrectVideo && hasCorrectContainer && subtitlesAreCorrect && hasAc3 && hasAac) {
      return true;
    }
    return false;
  };

  if (isFilePerfect()) {
    response.infoLog += `☑️ File is already perfect (MP4/${inputs.target_codec}). Skipping.\n`;
    return response;
  }

  // Encoder Logic
  let videoEncoderArgs = "";
  
  // GPU Encoding Path
  if (inputs.encoder_type === 'gpu_amd') {
    let encoder = '';
    if (inputs.target_codec === 'h265') encoder = 'hevc_amf';
    else if (inputs.target_codec === 'av1') encoder = 'av1_amf';
    else encoder = 'h264_amf';
    
    videoEncoderArgs = `-c:v ${encoder} -quality balanced -rc cqp -qp_i ${inputs.quality_level} -qp_p ${inputs.quality_level}`;
    response.infoLog += `⚡ GPU Encoding selected: ${encoder}\n`;
  } 
  // CPU Encoding Path
  else {
    let encoder = '';
    if (inputs.target_codec === 'h265') encoder = 'libx265';
    else if (inputs.target_codec === 'av1') encoder = 'libsvtav1'; // Uses SVT-AV1 for performance
    else encoder = 'libx264';

    let tuneSetting = '';
    if (inputs.enable_smart_tuning === 'true' && (encoder === 'libx264' || encoder === 'libx265')) {
        const filename = (file.file || "").toLowerCase();
        if (filename.match(/\b(anime|animation|cartoon)\b/i)) tuneSetting = '-tune animation';
        else if ((file.meta?.year && file.meta.year < 2000) || filename.match(/\b(classic|grain)\b/i)) tuneSetting = '-tune grain';
        else tuneSetting = '-tune film';
    }

    // SVT-AV1 uses numeric presets. We map them for the user.
    let cpuPreset = inputs.cpu_speed_preset;
    if(encoder === 'libsvtav1') {
        const presetMap = { slower: 5, slow: 6, medium: 8, fast: 10, faster: 12 };
        cpuPreset = presetMap[inputs.cpu_speed_preset] || 8;
    }

    videoEncoderArgs = `-c:v ${encoder} -preset ${cpuPreset} ${tuneSetting} -crf ${inputs.quality_level}`;
    response.infoLog += `🐌 CPU Encoding selected: ${encoder}\n`;
  }

  // Retains the best audio/subtitle/scaling logic
  const audioStreams = file.ffProbeData.streams.filter(s => s.codec_type === 'audio');
  const subtitleStreams = file.ffProbeData.streams.filter(s => s.codec_type === 'subtitle');
  const audioLangs = ["da", "dan", "dansk", "en", "eng", "english", "und"];
  let selectedAudio = audioStreams.filter(a => audioLangs.includes((a.tags?.language || "und").toLowerCase()));
  if (selectedAudio.length === 0 && audioStreams.length > 0) selectedAudio = [audioStreams[0]];

  let audioMaps = "", audioCodecs = "";
  selectedAudio.forEach((audio, i) => {
    const streamIndex = audioStreams.indexOf(audio);
    const channels = audio.channels || 2;
    audioMaps += ` -map 0:a:${streamIndex} -map 0:a:${streamIndex}`;
    audioCodecs += ` -c:a:${i*2} ac3 -b:a:${i*2} ${channels >= 6 ? '448k' : '384k'} -ac:a:${i*2} 6 -c:a:${i*2+1} aac -b:a:${i*2+1} 160k -ac:a:${i*2+1} 2`;
  });
  
  let subtitleMap = "";
  if (inputs.keep_subtitles === 'true' && subtitleStreams.length > 0) {
    subtitleMap = " -map 0:s? -c:s copy";
  }

  const is4K = videoStream.width > 1920;
  let scaleFilter = "";
  if (inputs.force_1080p === "true" && is4K) {
    scaleFilter = "-vf scale=1920:-2:flags=lanczos ";
  }

  // Final command assembly
  response.preset = `, -map 0:v${audioMaps}${subtitleMap} ${scaleFilter}-pix_fmt yuv420p ${videoEncoderArgs}${audioCodecs} -movflags +faststart`;
  response.processFile = true;

  response.infoLog += `\n✅ Ready for Titan-level encoding!\n`;
  response.infoLog += `├─ Codec: ${inputs.target_codec}\n`;
  response.infoLog += `├─ Encoder: ${inputs.encoder_type}\n`;
  response.infoLog += `├─ Quality: ${inputs.quality_level}\n`;
  response.infoLog += `└─ Subtitles: ${inputs.keep_subtitles === 'true' ? 'Kept' : 'Removed'}\n`;

  return response;
};


module.exports.details = details;
module.exports.plugin = plugin;