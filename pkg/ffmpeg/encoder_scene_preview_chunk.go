package ffmpeg

import (
	"fmt"
	"strconv"

	"github.com/stashapp/stash/pkg/utils"
)

type ScenePreviewChunkOptions struct {
	Time       int
	Width      int
	OutputPath string
}

func (e *Encoder) ScenePreviewVideoChunk(probeResult VideoFile, options ScenePreviewChunkOptions, preset string, fallback bool) error {
	fallbackMinSlowSeek := 20
	fastSeek := options.Time
	slowSeek := 0

	args := []string{
		"-v", "error",
	}

	// Not fallback: enable xerror
	if !fallback {
		args = append(args, "-xerror")
	} else {
		// Fallback try a combination of fast/slow seek instead of only fastseek
		if fastSeek > fallbackMinSlowSeek {
			fastSeek = fastSeek - fallbackMinSlowSeek
			slowSeek = fallbackMinSlowSeek
		} else {
			slowSeek = fastSeek
			fastSeek = 0
		}
	}

	if fastSeek > 0 {
		args = append(args, "-ss")
		args = append(args, strconv.Itoa(fastSeek))
	}

	args = append(args, "-i")
	args = append(args, probeResult.Path)

	if slowSeek > 0 {
		args = append(args, "-ss")
		args = append(args, strconv.Itoa(slowSeek))
	}

	args2 := []string{
		"-t", "0.75",
		"-max_muxing_queue_size", "1024", // https://trac.ffmpeg.org/ticket/6375
		"-y",
		"-c:v", "libx264",
		"-pix_fmt", "yuv420p",
		"-profile:v", "high",
		"-level", "4.2",
		"-movflags", "+faststart",
		"-pix_fmt", "yuv420p",
		"-preset", preset,
		"-crf", "21",
		"-threads", "4",
		"-vf", fmt.Sprintf("scale=%v:-2", options.Width),
		"-c:a", "aac",
		"-b:a", "128k",
		"-strict", "-2",
		options.OutputPath,
	}

	finalArgs := append(args, args2...)

	_, err := e.run(probeResult, finalArgs)
	return err
}

func (e *Encoder) ScenePreviewVideoChunkCombine(probeResult VideoFile, concatFilePath string, outputPath string) error {
	args := []string{
		"-v", "error",
		"-f", "concat",
		"-i", utils.FixWindowsPath(concatFilePath),
		"-y",
		"-c", "copy",
		outputPath,
	}
	_, err := e.run(probeResult, args)
	return err
}

func (e *Encoder) ScenePreviewVideoToImage(probeResult VideoFile, width int, videoPreviewPath string, outputPath string) error {
	args := []string{
		"-v", "error",
		"-i", videoPreviewPath,
		"-y",
		"-c:v", "libwebp",
		"-lossless", "1",
		"-q:v", "70",
		"-compression_level", "6",
		"-preset", "default",
		"-loop", "0",
		"-threads", "4",
		"-vf", fmt.Sprintf("scale=%v:-2,fps=12", width),
		"-an",
		outputPath,
	}
	_, err := e.run(probeResult, args)
	return err
}
