use hound::Sample;
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
    let output_device = host
        .default_output_device()
        .expect(&format!("No available output device for host: {}", host.id()).to_string());

    let mut input_configs = input_device
        .supported_input_configs()
        .expect("error while querying configs");
    let mut output_configs = output_device
        .supported_output_configs()
        .expect("error while querying output configs");

    let input_config = input_configs
        .next()
        .expect("no supported config?!")
        .with_max_sample_rate();
    let output_config = output_configs
        .find(|c| {
            c.channels() == input_config.channels()
                && c.sample_format() == input_config.sample_format()
        })
        .map(|c| c.with_max_sample_rate())
        .unwrap_or_else(|| output_device.default_output_config().unwrap().into());

    println!("Input config: {:#?}", input_config);
    println!("Input device: {}", input_device.description()?);
    println!("Output config: {:#?}", output_config);
    println!("Output device: {}", output_device.description()?);

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
    let input_config = input_config.into();
    let output_config = output_config.into();
    let writer_clone = writer.clone();

    // Shared buffer for output audio
    let output_buffer = Arc::new(Mutex::new(Vec::<f32>::new()));
    let output_buffer_clone = output_buffer.clone();

    // Output stream
    let output_stream = output_device.build_output_stream(
        &output_config,
        move |output: &mut [f32], _| {
            let mut buffer = output_buffer_clone.lock().unwrap();
            let len = output.len().min(buffer.len());
            output[..len].copy_from_slice(&buffer[..len]);
            // Remove the samples that were just played
            buffer.drain(..len);
            // If not enough samples, fill the rest with silence
            if len < output.len() {
                for sample in &mut output[len..] {
                    *sample = 0.0;
                }
            }
        },
        err_fn,
        None,
    )?;

    let output_buffer_clone = output_buffer.clone();
    let input_stream = match sample_format {
        cpal::SampleFormat::U8 => input_device.build_input_stream(
            &input_config,
            move |data: &[u8], _: &InputCallbackInfo| {
                let mut writer = writer_clone.lock().unwrap();
                // Transform: convert u8 to i16 centered at 0
                let transformed: Vec<i16> = data.iter().map(|&s| (s as i16 - 128) << 8).collect();
                write_wav_samples(&mut *writer, &transformed);
                // Also convert to f32 for output
                let mut buffer = output_buffer_clone.lock().unwrap();
                buffer.extend(
                    data.iter()
                        .map(|&s| ((s as f32 - 128.0) / 128.0).clamp(-1.0, 1.0)),
                );
            },
            err_fn,
            None,
        )?,
        cpal::SampleFormat::I16 => input_device.build_input_stream(
            &input_config,
            move |data: &[i16], _: &InputCallbackInfo| {
                let mut writer = writer_clone.lock().unwrap();
                write_wav_samples(&mut *writer, data);
                // Also convert to f32 for output
                let mut buffer = output_buffer_clone.lock().unwrap();
                buffer.extend(
                    data.iter()
                        .map(|&s| (s as f32 / i16::MAX as f32).clamp(-1.0, 1.0)),
                );
            },
            err_fn,
            None,
        )?,
        cpal::SampleFormat::F32 => input_device.build_input_stream(
            &input_config,
            move |data: &[f32], _: &InputCallbackInfo| {
                let mut writer = writer_clone.lock().unwrap();
                write_wav_samples(&mut *writer, data);
                // Directly copy to output buffer
                let mut buffer = output_buffer_clone.lock().unwrap();
                buffer.extend_from_slice(data);
            },
            err_fn,
            None,
        )?,
        _ => panic!("Unsupported sample format for generic WAV writer"),
    };

    let _ = output_stream.play();
    let _ = input_stream.play();

    println!("Recording and playing for 5 seconds...");
    std::thread::sleep(std::time::Duration::from_secs(5));
    drop(input_stream);
    drop(output_stream);
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

/// Generic WAV writing function for supported sample types
fn write_wav_samples<T: Sample + Copy>(
    writer: &mut hound::WavWriter<std::io::BufWriter<std::fs::File>>,
    data: &[T],
) {
    for &sample in data {
        let _ = writer.write_sample(sample);
    }
}

fn err_fn(err: cpal::StreamError) {
    eprintln!("an error occurred on stream: {err}");
}
