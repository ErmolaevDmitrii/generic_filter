#!/usr/bin/env python3

import argparse
import csv
import io
import math
import os


def sinc(value):
    if abs(value) < 1e-12:
        return 1.0
    return math.sin(math.pi * value) / (math.pi * value)


def lowpass_coefficients(taps, width, cutoff):
    middle = (taps - 1) / 2
    coefficients = []
    for index in range(taps):
        offset = index - middle
        window = 0.54 - 0.46 * math.cos(2 * math.pi * index / (taps - 1))
        coefficients.append(2 * cutoff * sinc(2 * cutoff * offset) * window)

    scale = (1 << (width - 1)) - 1
    gain = sum(coefficients)
    quantized = [round(value * scale / gain) for value in coefficients]

    correction = scale - sum(quantized)
    quantized[taps // 2] += correction
    return quantized


def chirp_samples(
    count,
    width,
    amplitude,
    start_frequency,
    stop_frequency,
):
    limit = (1 << (width - 1)) - 1
    if not 0 <= amplitude <= limit:
        raise ValueError("amplitude must be in range 0..{}".format(limit))

    phase = 0.0
    samples = []
    for index in range(count):
        progress = index / max(count - 1, 1)
        frequency = start_frequency + progress * (stop_frequency - start_frequency)
        phase += 2 * math.pi * frequency
        samples.append(round(amplitude * math.sin(phase)))
    return samples


def fir(samples, coefficients):
    result = []
    for sample_index in range(len(samples)):
        accumulator = 0
        for tap_index, coefficient in enumerate(coefficients):
            if sample_index >= tap_index:
                accumulator += samples[sample_index - tap_index] * coefficient
        result.append(accumulator)
    return result


def write_lines(path, values):
    with io.open(path, "w", encoding="utf-8") as output:
        output.write("".join("{}\n".format(value) for value in values))


def write_csv(path, samples, expected):
    with io.open(path, "w", encoding="utf-8", newline="") as output:
        writer = csv.writer(output)
        writer.writerow(("sample_index", "input", "expected"))
        writer.writerows(zip(range(len(samples)), samples, expected))


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", default="sim/build/fp_rd_chirp")
    parser.add_argument("--sample-count", type=int, default=256)
    parser.add_argument("--taps", type=int, default=16)
    parser.add_argument("--input-width", type=int, default=16)
    parser.add_argument("--coeff-width", type=int, default=16)
    parser.add_argument("--amplitude", type=int, default=12000)
    parser.add_argument("--start-frequency", type=float, default=0.01)
    parser.add_argument("--stop-frequency", type=float, default=0.45)
    parser.add_argument("--cutoff", type=float, default=0.18)
    return parser.parse_args()


def main():
    args = parse_args()
    if args.taps < 2:
        raise ValueError("taps must be at least 2")
    if not 0 < args.cutoff < 0.5:
        raise ValueError("cutoff must be between 0 and 0.5")

    output_dir = args.out_dir
    if not os.path.isdir(output_dir):
        os.makedirs(output_dir)

    coefficients = lowpass_coefficients(args.taps, args.coeff_width, args.cutoff)
    samples = chirp_samples(
        args.sample_count,
        args.input_width,
        args.amplitude,
        args.start_frequency,
        args.stop_frequency,
    )
    expected = fir(samples, coefficients)

    write_lines(os.path.join(output_dir, "coeffs.txt"), coefficients)
    write_lines(os.path.join(output_dir, "samples.txt"), samples)
    write_lines(os.path.join(output_dir, "expected.txt"), expected)
    write_csv(os.path.join(output_dir, "response.csv"), samples, expected)
    print("Generated {} samples in {}".format(len(samples), output_dir))


if __name__ == "__main__":
    main()
