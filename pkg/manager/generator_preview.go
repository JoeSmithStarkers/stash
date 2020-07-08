package manager

import (
	"bufio"
	"fmt"
	"github.com/stashapp/stash/pkg/ffmpeg"
	"github.com/stashapp/stash/pkg/logger"
	"github.com/stashapp/stash/pkg/utils"
	"os"
	"path/filepath"
)

type PreviewGenerator struct {
	Info *GeneratorInfo

	VideoChecksum	string
	VideoFilename   string
	ImageFilename   string
	OutputDirectory string

	GenerateVideo bool
	GenerateImage bool

	PreviewPreset string
}

func NewPreviewGenerator(videoFile ffmpeg.VideoFile, videoChecksum string, videoFilename string, imageFilename string, outputDirectory string, generateVideo bool, generateImage bool, previewPreset string) (*PreviewGenerator, error) {
	exists, err := utils.FileExists(videoFile.Path)
	if !exists {
		return nil, err
	}
	generator, err := newGeneratorInfo(videoFile)
	if err != nil {
		return nil, err
	}
	generator.ChunkCount = 12 // 12 segments to the preview
	if err := generator.configure(); err != nil {
		return nil, err
	}

	return &PreviewGenerator{
		Info:            generator,
		VideoChecksum:   videoChecksum,
		VideoFilename:   videoFilename,
		ImageFilename:   imageFilename,
		OutputDirectory: outputDirectory,
		GenerateVideo:   generateVideo,
		GenerateImage:   generateImage,
		PreviewPreset:   previewPreset,
	}, nil
}

func (g *PreviewGenerator) Generate() error {
	logger.Infof("[generator] generating scene preview for %s", g.Info.VideoFile.Path)
	encoder := ffmpeg.NewEncoder(instance.FFMPEGPath, instance.NicePath)

	if err := g.generateConcatFile(); err != nil {
		return err
	}

	if g.GenerateVideo {
		if err := g.generateVideo(&encoder, false); err != nil {
			logger.Warnf("[generator] failed generating scene preview, trying fallback")
			if err := g.generateVideo(&encoder, true); err != nil {
				return err
			}
		}
	}
	if g.GenerateImage {
		if err := g.generateImage(&encoder); err != nil {
			return err
		}
	}
	return nil
}

func (g *PreviewGenerator) generateConcatFile() error {
	f, err := os.Create(g.getConcatFilePath())
	if err != nil {
		return err
	}
	defer f.Close()

	w := bufio.NewWriter(f)
	for i := 0; i < g.Info.ChunkCount; i++ {
		num := fmt.Sprintf("%.3d", i)
		filename := "preview_" + g.VideoChecksum + "_" + num + ".mp4"
		_, _ = w.WriteString(fmt.Sprintf("file '%s'\n", filename))
	}
	return w.Flush()
}

func (g *PreviewGenerator) generateVideo(encoder *ffmpeg.Encoder, fallback bool) error {
	outputPath := filepath.Join(g.OutputDirectory, g.VideoFilename)
	outputExists, _ := utils.FileExists(outputPath)
	if outputExists {
		return nil
	}

	stepSize := int(g.Info.VideoFile.Duration / float64(g.Info.ChunkCount))
	for i := 0; i < g.Info.ChunkCount; i++ {
		time := i * stepSize
		num := fmt.Sprintf("%.3d", i)
		filename := "preview_" + g.VideoChecksum + "_" + num + ".mp4"
		chunkOutputPath := instance.Paths.Generated.GetTmpPath(filename)

		options := ffmpeg.ScenePreviewChunkOptions{
			Time:       time,
			Width:      640,
			OutputPath: chunkOutputPath,
		}
		if err := encoder.ScenePreviewVideoChunk(g.Info.VideoFile, options, g.PreviewPreset, fallback); err != nil {
			return err
		}
	}

	videoOutputPath := filepath.Join(g.OutputDirectory, g.VideoFilename)
	if err := encoder.ScenePreviewVideoChunkCombine(g.Info.VideoFile, g.getConcatFilePath(), videoOutputPath) ; err != nil {
		return err
	}
	logger.Debug("created video preview: ", videoOutputPath)
	return nil
}

func (g *PreviewGenerator) generateImage(encoder *ffmpeg.Encoder) error {
	outputPath := filepath.Join(g.OutputDirectory, g.ImageFilename)
	outputExists, _ := utils.FileExists(outputPath)
	if outputExists {
		return nil
	}

	videoPreviewPath := filepath.Join(g.OutputDirectory, g.VideoFilename)
	tmpOutputPath := instance.Paths.Generated.GetTmpPath(g.ImageFilename)
	if err := encoder.ScenePreviewVideoToImage(g.Info.VideoFile, 640, videoPreviewPath, tmpOutputPath); err != nil {
		return err
	}
	if err := utils.SafeMove(tmpOutputPath, outputPath); err != nil {
		return err
	}
	logger.Debug("created video preview image: ", outputPath)

	return nil
}

func (g *PreviewGenerator) getConcatFilePath() string {
	return instance.Paths.Generated.GetTmpPath(fmt.Sprintf("files_%s.txt", g.VideoChecksum))
}
