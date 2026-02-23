use std::sync::{Arc, Mutex};

use hound;

use cpal::{
    InputCallbackInfo,
    traits::{DeviceTrait, HostTrait, StreamTrait},
};

use anyhow::Result;

fn main() -> Result<()> {
    let host = cpal::default_host();
    let input_device = host
        .default_input_device()
        .expect(&format!("No available input device for host: {}", host.id()).to_string());

    let mut input_configs = input_device
        .supported_input_configs()
        .expect("error while querying configs");

    let input_config = input_configs
        .next()
        .expect("no supported config?!")
        .with_max_sample_rate();

    println!("Input config: {:#?}", input_config);
    println!("Input device: {}", input_device.description()?);

    // Remove output file if it exists
    let output_path = "output.wav";
    let _ = std::fs::remove_file(output_path);

    let spec = hound::WavSpec {
        channels: input_config.channels(),
        sample_rate: input_config.sample_rate(),
        bits_per_sample: match input_config.sample_format() {
            cpal::SampleFormat::I16 => 16,
            cpal::SampleFormat::U16 => 16,
            cpal::SampleFormat::U8 => 16, // We'll convert to i16
            cpal::SampleFormat::F32 => 32,
            _ => panic!("Unsupported sample format for WAV"),
        },
        sample_format: match input_config.sample_format() {
            cpal::SampleFormat::I16 => hound::SampleFormat::Int,
            cpal::SampleFormat::U16 => hound::SampleFormat::Int,
            cpal::SampleFormat::U8 => hound::SampleFormat::Int,
            cpal::SampleFormat::F32 => hound::SampleFormat::Float,
            _ => panic!("Unsupported sample format for WAV"),
        },
    };

    let writer = Arc::new(Mutex::new(hound::WavWriter::create(output_path, spec)?));
    let sample_format = input_config.sample_format();
    let config = input_config.into();
    let writer_clone = writer.clone();

    let input_stream = match sample_format {
        cpal::SampleFormat::U8 => input_device.build_input_stream(
            &config,
            move |data: &[u8], _: &InputCallbackInfo| {
                let mut writer = writer_clone.lock().unwrap();
                for &sample in data {
                    // Convert u8 to i16 (centered at 0)
                    let s = (sample as i16 - 128) << 8;
                    let _ = writer.write_sample(s);
                }
            },
            err_fn,
            None,
        )?,
        cpal::SampleFormat::I16 => input_device.build_input_stream(
            &config,
            move |data: &[i16], _: &InputCallbackInfo| {
                let mut writer = writer_clone.lock().unwrap();
                for &sample in data {
                    let _ = writer.write_sample(sample);
                }
            },
            err_fn,
            None,
        )?,
        cpal::SampleFormat::U16 => input_device.build_input_stream(
            &config,
            move |data: &[u16], _: &InputCallbackInfo| {
                let mut writer = writer_clone.lock().unwrap();
                for &sample in data {
                    // Convert u16 to i16 (centered at 0)
                    let s = (sample as i32 - 32768) as i16;
                    let _ = writer.write_sample(s);
                }
            },
            err_fn,
            None,
        )?,
        cpal::SampleFormat::F32 => input_device.build_input_stream(
            &config,
            move |data: &[f32], _: &InputCallbackInfo| {
                let mut writer = writer_clone.lock().unwrap();
                for &sample in data {
                    let _ = writer.write_sample(sample);
                }
            },
            err_fn,
            None,
        )?,
        cpal::SampleFormat::I8 => todo!(),
        cpal::SampleFormat::I24 => todo!(),
        cpal::SampleFormat::I32 => todo!(),
        cpal::SampleFormat::I64 => todo!(),
        cpal::SampleFormat::U24 => todo!(),
        cpal::SampleFormat::U32 => todo!(),
        cpal::SampleFormat::U64 => todo!(),
        cpal::SampleFormat::F64 => todo!(),
        _ => todo!(),
    };

    let _ = input_stream.play();

    println!("Recording for 5 seconds...");
    std::thread::sleep(std::time::Duration::from_secs(5));
    drop(input_stream);
    let _ = Arc::try_unwrap(writer).map(|w| w.into_inner().unwrap().finalize());
    println!("Done! Audio written to output.wav");

    #[cfg(target_os = "windows")]
    {
        use std::process::Command;
        let _ = Command::new("powershell")
            .args([
                "-c",
                "(New-Object Media.SoundPlayer 'output.wav').PlaySync()",
            ])
            .status();
    }
    Ok(())
}

fn err_fn(err: cpal::StreamError) {
    eprintln!("an error occurred on stream: {err}");
}
