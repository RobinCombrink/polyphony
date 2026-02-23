use std::sync::Arc;

use cpal::{
    Data, FromSample, InputCallbackInfo, OutputCallbackInfo, Sample, SampleFormat,
    traits::{DeviceTrait, HostTrait, StreamTrait},
};
use ringbuf::{
    HeapRb, SharedRb,
    producer::DelegateProducer,
    storage::Heap,
    traits::{Consumer, Producer, Split},
    wrap::caching::Caching,
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

    let mut output_configs = output_device
        .supported_output_configs()
        .expect("error while querying output configs");

    let output_config = output_configs
        .next()
        .expect("no supported output config?!")
        .with_max_sample_rate();

    let mut input_configs = input_device
        .supported_input_configs()
        .expect("error while querying configs");

    let input_config = input_configs
        .next()
        .expect("no supported config?!")
        .with_max_sample_rate();

    let latency_frames = (3_000.0 / 1_000.0) * input_config.sample_rate() as f32;
    let latency_samples = latency_frames as usize * input_config.channels() as usize;

    let ring = HeapRb::<u8>::new(latency_samples * 2);
    let (mut producer, consumer) = ring.split();

    for _ in 0..latency_samples {
        producer.try_push(0).unwrap();
    }

    let input_callback = create_input_callback(producer);

    let output_callback = create_output_callback(consumer, 0);

    println!(
        "Input Configs: {:#?}",
        input_configs
            .map(|config| config.sample_format().clone())
            .collect::<Vec<_>>()
    );

    println!("Input config: {:#?}", input_config);
    println!("Output config: {:#?}", output_config);

    println!("Input device: {}", input_device.description()?);

    let input_stream =
        input_device.build_input_stream(&input_config.into(), input_callback, err_fn, None)?;
    let output_stream =
        output_device.build_output_stream(&output_config.into(), output_callback, err_fn, None)?;

    input_stream.play();
    output_stream.play();

    println!("Playing for some seconds... ");
    std::thread::sleep(std::time::Duration::from_secs(5));
    drop(input_stream);
    drop(output_stream);
    println!("Done!");
    Ok(())
}

fn create_input_callback<T, P>(
    mut producer: P,
) -> impl FnMut(&[T], &InputCallbackInfo) + Send + 'static
where
    T: Copy + Send + 'static,
    P: Producer<Item = T> + Send + 'static,
{
    move |data: &[T], _: &InputCallbackInfo| {
        let mut output_fell_behind = false;

        for &sample in data {
            if producer.try_push(sample).is_err() {
                output_fell_behind = true;
            }
        }

        if output_fell_behind {
            eprintln!("output stream fell behind: try increasing latency");
        }
    }
}

fn create_output_callback<T, P>(
    mut consumer: P,
    default_sample: T,
) -> impl FnMut(&mut [T], &OutputCallbackInfo) + Send + 'static
where
    T: Copy + Send + 'static,
    P: Consumer<Item = T> + Send + 'static,
{
    move |data: &mut [T], _: &OutputCallbackInfo| {
        let mut input_fell_behind = false;
        for sample in data {
            *sample = match consumer.try_pop() {
                Some(s) => s,
                None => {
                    input_fell_behind = true;
                    default_sample
                }
            };
        }
        if input_fell_behind {
            eprintln!("input stream fell behind: try increasing latency");
        }
    }
}

fn err_fn(err: cpal::StreamError) {
    eprintln!("an error occurred on stream: {err}");
}
