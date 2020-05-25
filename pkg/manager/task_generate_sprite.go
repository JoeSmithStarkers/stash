package manager

import (
	"github.com/stashapp/stash/pkg/ffmpeg"
	"github.com/stashapp/stash/pkg/logger"
	"github.com/stashapp/stash/pkg/models"
	"github.com/stashapp/stash/pkg/utils"
	"github.com/remeh/sizedwaitgroup"
)

type GenerateSpriteTask struct {
	Scene models.Scene
}

func (t *GenerateSpriteTask) Start(wg *sizedwaitgroup.SizedWaitGroup) {
	defer wg.Done()

	videoChecksum := t.Scene.Checksum
	if t.doesSpriteExist(videoChecksum) {
		return
	}

	videoFile, err := ffmpeg.NewVideoFile(instance.FFProbePath, t.Scene.Path)
	if err != nil {
		logger.Errorf("error reading video file: %s", err.Error())
		return
	}

	imagePath := instance.Paths.Scene.GetSpriteImageFilePath(videoChecksum)
	vttPath := instance.Paths.Scene.GetSpriteVttFilePath(videoChecksum)
	generator, err := NewSpriteGenerator(*videoFile, videoChecksum, imagePath, vttPath, 9, 9)
	if err != nil {
		logger.Errorf("error creating sprite generator: %s", err.Error())
		return
	}

	if err := generator.Generate(); err != nil {
		logger.Errorf("error generating sprite: %s", err.Error())
		return
	}
}

func (t *GenerateSpriteTask) doesSpriteExist(sceneChecksum string) bool {
	imageExists, _ := utils.FileExists(instance.Paths.Scene.GetSpriteImageFilePath(sceneChecksum))
	vttExists, _ := utils.FileExists(instance.Paths.Scene.GetSpriteVttFilePath(sceneChecksum))
	return imageExists && vttExists
}
