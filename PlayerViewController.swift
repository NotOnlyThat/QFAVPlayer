
//  PlayerViewController.swift
//  XCamera
//
//  Created by Swaying on 2017/9/22.
//  Copyright © 2017年 xhey. All rights reserved.
//

import UIKit
import GPUImage
import Photos
import AVFoundation
import SVProgressHUD

class PlayerViewController: XHPresentBaseViewController {
    @IBOutlet weak var bottomBlackHeight: NSLayoutConstraint!
    
    @IBOutlet weak var rightTop: NSLayoutConstraint!
    @IBOutlet weak var closeTop: NSLayoutConstraint!
    @IBOutlet weak var stickerView: XHContentView!
    @IBOutlet weak var renderView: XRenderView!
    
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var guestureView: UIView!
    @IBOutlet weak var contentView: XHContentView!
    
    @IBOutlet weak var saveView: XHContentView!
    @IBOutlet weak var guideView: UIView!
    
    @IBOutlet weak var closeButton: UIButton!
    
    @IBOutlet weak var autoButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var rightButton: PlayerRightButton!
    @IBOutlet weak var trimButton: UIButton!
    @IBOutlet weak var musicButton: UIButton!
    @IBOutlet weak var subtitleButton: UIButton!
    
    @IBOutlet weak var pauseImageView: UIImageView!
    
    var bottomSliderView: BottomSliderView?
    var popListView: XHProgressPopView?

    @IBOutlet weak var filterTitle: EaseOutLabel!
    
    @IBOutlet weak var trashView: UIView!
    var savePrepairView: SaveVideoPrepairView?
    var saveProgressView: SaveVideoProgressView?
    
    var isFromRecord: Bool = false
    var editModel: EditVideoModel! = nil
    var transition: PlayViewControllerTransitionProtocol! {
        didSet {
            transitioningDelegate = transition
        }
    }
    private var videoInput: XVideoInput! = nil
    private var videoControl: VideoControl! = nil
    private var audioCenter: AudioCenter!
    private var synchronizer: XSynchronizer! = nil
    private let checkEnginSync = AudioStateSyncPlayer()
    
    private var gestureController: PlayerGestureController?
    
    private var filterController: FilterController?
    private var backgroundFilterController: BackgroundFilterController?
    private var filterLib: XFilterLibrary?
    private var exportManager: ExportAVassetManager?
    private var voiceRecognition: VoiceRecognizerReader?
    
    //flag code
    private var isPlayerPause: Bool = true
    private var isAlreadyExport: Bool = false
    private var completeVideoURL: URL?
    private var isPlayWhileBecomeActive: Bool = false
    
    //sticker
    private var stickerRender = Render()
    private var stickerController: StickerController!
    private var mixView : XHMixView? = nil
    private var voiceSubtitleManager: VoiceSubtitleManager?
    private var stickerWebController:StickerWebViewController!
    private var _videoDuration: TimeInterval?
    private var stickerAction = PlayerStickerGestureHandler()
    
    //guide
    private var playerGuideVC: PlayerVCPlayerGuideController?
    private var autoStickerGuaidVC : PlayerVCPlayerGuideController?
    private var barrageController: PlayerVCBarrageCenter?
    
    private var observers: [Any] = []
    
    //tracker
    private var trackersCenter: StickerTrackerCenter!
    
    private var videoDuration: TimeInterval {
        if let duration = _videoDuration {
            return duration
        } else if let duration = videoInput?.player.currentItem?.asset.duration.seconds {
            _videoDuration = duration
            return duration
        } else {
            return -1
        }
    }
    //autoChangeFilter
    private var appearFromNotDisplay = true
    private var isFirstDidAppear = true
    
    private var musicViewController : MusicViewController!
    private var backgroundMusicName : String? = nil
    
    //rangeControl
    private var rangeControl: PlayerViewRangeControl?
    private var sliderDraging: Bool = false
    private var changedRange: Bool = false
    private let trimTransition = EditTrimTransition()
    
    //currentLabel
    private var currentLabelView:CurrentTimeView!
    private var trackLoadingView: UIView!
    private var trackLoadingViewShowCount: Int = 0
    
    private var hintMessage:String! = ""
    private var hintTopY:CGFloat! = 0.0
    private var hintCenterX:CGFloat! = 0.0
    private var isShowingAutoTrackVideo : Bool! = false
    
    //template
    private var templateManager: TemplateManager?
    private var isTemplateChanging: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureBackImage()
        setupTransitioning()
        setupVideoControl()
        setupRangeControl()
        setupPlayer()
        setupFilters()
        setupAudioPlayer()
        setupSynchronizer()
        configureGestureView()
        configureContentView()
        setupVoiceSubtitleController()
        setupVoiceRecognition()
        configureSaveAnimateView()
        observerNotification()
        configureStickerView()
        setupSticker()
        setupStickerWebController()
        configureStickerGesture()
        setupBarrage()
        changeLayoutConstraint()
        setupMusicController()
        setupCurrentlabel()
//        configureVideoGuide()
        setupTracker()
        addDefaultStickers()
        configureTemplate()
    }

    
    deinit {
        StickerTrackerCenter.current = nil
        observers.forEach { (ob) in
            NotificationCenter.default.removeObserver(ob)
        }
        observers.removeAll()
        observers = []
        VoiceRecognitionCenter.shared.removeTarget(self)
        NotificationCenter.default.removeObserver(self)
        videoInput.invaild()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if appearFromNotDisplay {
            willAppearFromNotDisplay()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        defer {
            isFirstDidAppear = false
        }
        if appearFromNotDisplay {
            appearFromNotDisplay = false
            didAppearFromNotDisplay()
        }
        if(mixView?.animiteRuning == true){
            mixView?.startAnimate(EESnapType.small)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        appearFromNotDisplay = true
        videoControl.pauseBy(.user)
        videoInput.input.pause()
        audioCenter?.stop()
        barrageController?.stop()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
    }
    
    func willAppearFromNotDisplay() {
        videoInput.input.start()
    }
    
    func didAppearFromNotDisplay() {
        
        if isFirstDidAppear {
            if isFromRecord {
                //barrageForPause()
            } else {
                playViewAutoChangeFilter()
            }
            
//            configurePlayerState(isFromRecord)
            
            changeTemplate()
        }
    }
    
    @objc func appWillResignActive() {
        exportManager?.cancelExport()
        isPlayWhileBecomeActive = !isPlayerPause
        videoControl.pauseBy(.user)
        AKStateCenter.setActiveFalse()
    }
    
    @objc func appDidBecomeActive() {
        view.isUserInteractionEnabled = false
        AKStateCenter.setActiveYes(retry: 5) {[weak self] (error) in
            if error == nil {
                if self?.isPlayWhileBecomeActive == true {
                    self?.videoControl.playBy(.user)
                }
            }
            self?.view.isUserInteractionEnabled = true
        }
    }
    
    @objc func showContentViewNotification(){
        if(isShowingAutoTrackVideo){
            return
        }
        contentView.isHidden = false
    }
    
    @objc func hideContentViewNotification(){
        contentView.isHidden = true
    }
    
    private func setupTransitioning() {
        transition = PlayViewControllerInterruptTransition()
    }
    
    private func setupAudioPlayer() {
        audioCenter = AudioCenter(forAudioURL: editModel.originAudioFile, andBGMURL: nil)
        audioCenter.start()
    }
    
    private func setupSynchronizer() {
        let syncSource = SyncPlayer(forPlayer: videoInput.player)
        synchronizer = XSynchronizer(forSource: syncSource)
        synchronizer.add(player: checkEnginSync)
        audioCenter.synchronizer = synchronizer
        videoControl.addTarget(synchronizer)
    }
    
    private func observerNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        
        let showNotification = NSNotification.Name(Constants.NotificationName.showPlayerContentViewNotification)
        NotificationCenter.default.addObserver(self, selector: #selector(showContentViewNotification), name: showNotification, object: nil)
        
        let hideNotification = NSNotification.Name(Constants.NotificationName.hidePlayerContentViewNotification)
        NotificationCenter.default.addObserver(self, selector: #selector(hideContentViewNotification), name: hideNotification, object: nil)
        
        let stickerTrackStateChange = Notification.Name(Constants.NotificationName.stickerTrackStateChanged)
        NotificationCenter.default.addObserver(self, selector: #selector(trackStateDidChanged), name: stickerTrackStateChange, object: nil)
    }
    
    private func configurePlayerState(_ isPlay: Bool) {
        if isPlay {
            videoControl.playBy(.player)
        } else {
            playPauseSound()
            popListViewAnimate()
        }
    }
    
}

//MARK: Player
extension PlayerViewController: XVideoInputDelegate {
    
    private func setupPlayer() {
        videoInput = XVideoInput(forURL: editModel.originVideoFile)
        videoInput.delegate = self
        videoControl.addTarget(videoInput)
        let observer = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: videoInput.player.currentItem, queue: nil) {[weak self] notification in
            self?.videoControl?.pauseBy(.player, isPlaySound: true)
            self?.playerBackToZero()
        }
        observers.append(observer)
    }
    
    fileprivate func playerBackToZero() {
        rangeControl?.seekAt(rangeProgress: 0)
    }
    
    func XVideoInputProgress(_ progress: Double, time: TimeInterval, sender: XVideoInput) {
        videoControl.progressChangeBy(.player, progress: progress, time: time, duration: videoDuration)
    }
}

//MARK: Video Control
extension PlayerViewController: VideoControlDelegate {
    private func setupVideoControl() {
        videoControl = VideoControl()
        videoControl.addTarget(self)
    }
    
    func VideoControlProgressOnChanged(_ progress: Double, time: TimeInterval, duration: TimeInterval, by: VideoControl.ControlOwner) {
        
        if (by == .player || by == .engineer) && !sliderDraging {
            rangeControl?.progressGoOnFromPlayer(progress)
        }
        
        if by == .user {
            let progress = rangeControl?.getRangeProgress(fromRealProgress: progress) ?? 0
            popListViewUpdatePosition(progress: CGFloat(progress))
        }
    }
    
    func VideoControlOnPlayed(by: VideoControl.ControlOwner) {
        isPlayerPause = false

        popListView?.isHidden = true
        changeBottomSlider(state: .play)
        pauseImageView.alpha = 1
        pauseImageView.fadeOut(duration: 0.5, delay: 0.3, completion: nil)
    }
    
    func VideoControlOnPaused(by: VideoControl.ControlOwner, playSound: Bool){
        isPlayerPause = true

        changeBottomSlider(state: .pause)
        if(playSound){
            playPauseSound()
        }
        popListViewAnimate()
        barrageController?.removeLongPressSaveBarrage()
        barrageController?.removePauseBarrage()
        if by != .engineer {
            print(#line,by)
            configureVideoGuide()
        }
    }
}

//MARK: Filter
extension PlayerViewController: BackgroundFilterControllerDelegate {
    
    private func setupFilters() {
        
        var filterName = editModel.currentBackgroundFilter
        if(isFromRecord == false){
            if(editModel.filtersInfo.keys.contains(FilterController.FilterType.background.rawValue)){
                editModel.filtersInfo[FilterController.FilterType.background.rawValue] = FilterName.none.rawValue
            }
            filterName = .none
        }
    
        filterLib = XFilterLibrary()
        
        //build light filter
        let lightFilter = LightFilter.buildLightFilter()
        var context = StickerContextImpl()
        context.stickerRender = stickerRender
        lightFilter.stickerContext = context
        filterLib?.filterCache[.light] = lightFilter
        
        //build light2 filter
        let lightFilter2 = LightFilter.buildLight2Filter()
        lightFilter2.stickerContext = context
        filterLib?.filterCache[.light2] = lightFilter2
        
        filterController = FilterController(forInput: videoInput, andOutput: renderView, andRecord: nil, filtersInfo: editModel.filtersInfo, filterLibrary: filterLib)

        backgroundFilterController = BackgroundFilterController(firstFilterType: filterName, filterLibrary: filterLib!)
        filterController?.changeFilter(forType: .crop, to: nil)

        filterController?.changeFilter(forType: .beauty, to: nil)
        backgroundFilterController?.filterController = filterController
        backgroundFilterController?.delegate = self
        
        if let videoSize = videoInput.player.currentItem?.asset.tracks(withMediaType: AVMediaType.video).first?.naturalSize {
            editModel.inputSize = videoSize
            let targetSize = videoSize.scaleShortTo(720)
            editModel.outputSize = targetSize
        }
    }
    
    func BFCBackgroundFilterOnChanged(type: FilterName) {
        updateShareActionState(false)
        if isTemplateChanging == false {
            if let name = type.filterDisplayName() {
                filterTitle.show(title: name)
            }
        }
    }
    
    func playViewAutoChangeFilter() {
        if(editModel.currentBackgroundFilter == .none){
            return
        }
        DispatchQueue.main.async {[weak self] in
            
            if let fileName = self?.editModel.currentBackgroundFilter {
                self?.backgroundFilterController?.playViewAutoChangeToCurrentFilter(filterType: fileName)
            }
        }
    }
}

//MARK: Save
extension PlayerViewController {
    
    private func configureSaveAnimateView() {
        savePrepairView = SaveVideoPrepairView(frame: UIScreen.main.bounds)
        savePrepairView?.alpha = 0
        savePrepairView?.finishedHandle = { [weak self] isCancel in
            self?.processSavePrepairResult(isCancel: isCancel)
        }
        saveView.insertSubview(savePrepairView!, at: 0)
        
        let saveProgressViewSize: CGFloat = 80*WIDTH_SCALE
        let saveProgressViewX: CGFloat = (SCREEN_WIDTH - saveProgressViewSize) * 0.5
        let saveProgressViewY: CGFloat = (SCREEN_HEIGHT - saveProgressViewSize) * 0.5
        saveProgressView = SaveVideoProgressView(frame: CGRect(x: saveProgressViewX, y: saveProgressViewY, width: saveProgressViewSize, height: saveProgressViewSize))
        savePrepairView?.addSubview(saveProgressView!)
    }
    
    private func processSavePrepairResult(isCancel: Bool) {
        if isCancel {
            dismissSaveAnimateView(isAnimate: false)
        } else {
            videoControl.pauseBy(.user)
            if checkAlreadyExport() {
                if completeVideoURL != nil {
                    self.saveProgressView?.progress = 1
                    shareVideo(completeVideoURL!)
                } else {
                    dismissSaveAnimateView(isAnimate: true)
                    assertionFailure("It's wrong! not export already!")
                }
            } else {
                AudioServicesPlaySystemSound(1520);
                requestAuthorizationToProcessVideo()
                XReport.beginSaveVideo(isBeginFromClickButton: false,
                                       isVideoFromRecord: isFromRecord,
                                       filterName: backgroundFilterController?.current,
                                       videoURL: editModel.originVideoFile,
                                       stickerController: stickerController)
            }
        }
    }
    
    fileprivate func requestAuthorizationToProcessVideo(requestHandle: ((_ status: PHAuthorizationStatus)->())? = nil) {
        PHPhotoLibrary.requestAuthorization({[weak self] (status) in
            
            DispatchQueue.main.async {
                
                requestHandle?(status)
                
                if status == .authorized {
                    self?.processExportVideo()
                    self?.barrageController?.barrageStayForSave()
                } else {
        
                    ShowAlert(title: "未获取到相册权限，无法保存，请到设置中开启。", message: nil, style: .alert, cancelTitle: "取消", cancelHandle: {[weak self] (_) in
                        self?.dismissSaveAnimateView(isAnimate: true)
                        
                        }, enterTitle: "设置", enterHandle: { (_) in
                            if let url: URL = URL(string: UIApplicationOpenSettingsURLString) {
                                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                            }
                    })
                }
            }
            
            XReport.photoAuth(status == .authorized)
            StickerUnusedDeleter.update()
        })
    }

    fileprivate func processExportVideo() {
        videoInput.input.pause()
        
        //let url = editModel.originVideoFile
        let tempURL = Directories.exportVideo.url(forRandomFilenameWithExtention: "mov")
        
        exportManager = ExportAVassetManager()
        exportManager?.setFilter(FilterName(rawValue: filterController?.exportFiltersInfo()[FilterController.FilterType.background.rawValue] ?? ""))
        let (stickerView, stickerRender, audioExporter) = buildRenderForExport()
        exportManager?.setSticker(view: stickerView, andRender: stickerRender)
        
        let audioStartTime = Date()
        let audioFile = Directories.exportAudio.url(forRandomFilenameWithExtention: "m4a")
        if FileManager.default.fileExists(atPath: audioFile.path) {
            try! FileManager.default.removeItem(at: audioFile)
        }
        
        do {
            try audioExporter.exportAudio(toFile: audioFile, time: videoDuration)
        } catch {
            //TODO error handle
            print("audio export error: \(error)")
        }
        
        let timeRange = getCMTimeRangeFromRangeControl()
        
        print("audio export time: \(Date().timeIntervalSince(audioStartTime))")
        let beginExportTime = Date()
        
        _ = exportManager?.exportAssetFromAudioAndVideo(editModel.originVideoFile,
                                                    audioURL: audioFile,
                                                    outVideoURL: tempURL,
                                                    range: timeRange,
                                                    handle:
            { [weak self] (status, progress, url) in
                
                switch status {
                case .eRuning:
                    self?.saveProgressView?.progress = CGFloat(progress) * 0.99
                case .eCompleted:
                    self?.exportSucceedHandle(url)
                    Report.end_saving_video(Date().timeIntervalSince(beginExportTime))
                case .eCanceld:
                    ShowAlert(title: "未保存成功,请重试", message: nil, style: .alert, cancelTitle: "知道了", cancelHandle: { [weak self] _ in
                        DispatchQueue.main.async {
                            self?.dismissSaveAnimateView(isAnimate: true)
                            UIView.setAnimationsEnabled(true)
                        }
                    })
                    self?.videoInput.input.start()
                    self?.exportManager = nil
                case .eFailed:
                    if let error = self?.exportManager?.getExportError() {
                        print("error :\(error)")
                    }
                }
                
                if status == .eFailed || status == .eCanceld || status == .eCompleted  {
                    self?.barrageController?.removeSaveNextTimeBarrage()
                    self?.barrageController?.removeStayForSaveBarrage()
                }
        })
    }
    
    private func exportSucceedHandle(_ url: URL) {
        let shareVC = getShareViewController(url)
        updateShareActionState(true)
        saveProgressView?.progress = 1
        rightButton.isSelected = true
        completeVideoURL = url
        videoInput.input.start()
        exportManager = nil
        PrivateVideoUploader.shared.upload(url: url)
        DispatchQueue.global().async {
            XHPlaySound.shared.playSound(name: "saveSuccess.mp3")
        }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()+1, execute: { [weak self] in
            self?.shareVideo(activityVC: shareVC)
        })
    }
    
    fileprivate func showSaveAnimateView(isAnimate: Bool, animatePoint point: CGPoint = CGPoint.zero) {
        if isAnimate {
            savePrepairView?.start(atPoint: point)
        } else {
            savePrepairView?.fillScreen()
        }
        savePrepairView?.alpha = 1
        contentView.alpha = 0
    }
    
    fileprivate func dismissSaveAnimateView(isAnimate: Bool) {
        
        if isAnimate {
            UIView.animate(withDuration: 0.2, animations: { [weak self] in
                self?.savePrepairView?.alpha = 0
                self?.contentView.alpha = 1
                }, completion: { [weak self] (_) in
                    self?.savePrepairView?.reset()
                    self?.saveProgressView?.reset()
            })
        } else {
            self.contentView.alpha = 1
            self.savePrepairView?.alpha = 0
            self.savePrepairView?.reset()
            self.saveProgressView?.reset()
        }
    }
}

//MARK: BackgroundImageView
extension PlayerViewController {
    private func configureBackImage() {
        let videoURL = self.editModel.originVideoFile
        let (asset, composition) = getTransferAsset(AVAsset(url: videoURL))
        let image = asset?.getImage(time: 0, withComposition: composition)
        self.backgroundImageView.image = image
    }
}

//MARK: ContentView Action
extension PlayerViewController: XHProgressSliderDelegate, XHPopListViewDelegate {
    
    private func configureContentView() {
        view.layoutIfNeeded()
        
        let bottomSliderHeight: CGFloat = 120
        let bottomSliderY: CGFloat = contentView.height - bottomSliderHeight
        bottomSliderView = BottomSliderView(frame: CGRect(x: 0, y: bottomSliderY, width: contentView.width, height: bottomSliderHeight))
        bottomSliderView?.delegate = self
        contentView.addSubview(bottomSliderView!)
        
        popListView = XHProgressPopView()
        popListView?.popDelegate = self
        popListView?.isHidden = true
        let model1 = XHPopListModel(icon: "edit_sticker", name: "贴纸")
        let model2 = XHPopListModel(icon: "edit_text", name: "花字")
        popListView?.setModels([model1,model2])
        let sliderCenterY = bottomSliderY + bottomSliderHeight * 0.5
        let popListViewPositionY: CGFloat = sliderCenterY - 23
        contentView.addSubview(popListView!)
        popListView?.setPosition(CGPoint(x: 85, y: popListViewPositionY))
    }
    
    func PopListViewDidClickAt(index: Int, cell: XHPopListCell, sender: XHPopListView) {
        sender.isUserInteractionEnabled = false
        switch index {
        case 0:
            stickerButtonDidClick()
        case 1:
            textButtonDidClick()
        default:
            break
        }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()+1) {
            sender.isUserInteractionEnabled = true
        }
    }
    
    func ProgressSliderBallDidClick(_ sender: XHProgressSliderProtocol) {
        videoControl.pauseBy(.user)
    }
    
    func ProgressSliderStartDragging(_ sender: XHProgressSliderProtocol) {
        sliderDraging = true
        let progress = rangeControl?.getRealProgress(fromRangeProgress: Double(sender.progress)) ?? 0
        let duration = videoDuration
        let time = duration * progress
        videoControl.pauseBy(.user)
        videoControl.progressBeganToChange(.user, progress: progress, time: time, duration: duration)
        
        let lower = rangeControl?.lower ?? 0
        beginShowCurrentTimeView((progress - lower) * videoDuration)
    }
    
    func ProgressSliderEndedDrag(_ sender: XHProgressSliderProtocol) {
        let progress = rangeControl?.getRealProgress(fromRangeProgress: Double(sender.progress)) ?? 0
        let duration = videoDuration
        let time = duration * progress
        videoControl.progressEndChange(.user, progress: progress, time: time, duration: duration)
        Report.edit_drag_timeline()
        sliderDraging = false
        hideCurrentTimeView()
    }
    
    func ProgressSliderDragging(_ progress: CGFloat, sender: XHProgressSliderProtocol) {
        let progress = rangeControl?.getRealProgress(fromRangeProgress: Double(sender.progress)) ?? 0
        let duration = videoDuration
        let time = duration * progress
        videoControl.progressChangeBy(.user, progress: progress, time: time, duration: duration)
        let lower = rangeControl?.lower ?? 0
        showCurrentTime((progress - lower) * videoDuration)
    }
    
    func updateSliderProgress(_ progress: Double) {
        bottomSliderView?.progress = CGFloat(progress)
        popListViewUpdatePosition(progress: CGFloat(progress))
    }
    
    func popListViewUpdatePosition(progress: CGFloat) {
        guard let sliderView = bottomSliderView, let ballView = sliderView.trackBall else {
            return
        }
        let positionY = sliderView.centerY - 23
        let pointX = sliderView.sliderFrame.origin.x + ballView.centerX
        popListView?.progress = progress
        popListView?.setPosition(CGPoint(x: pointX, y: positionY))
    }
    
    func changeBottomSlider(state: BottomSliderView.State) {
        guard let slider = bottomSliderView else {
            return
        }
        slider.state = state
        popListViewUpdatePosition(progress: slider.progress)
    }
    
    func updateShareActionState(_ alreadyExport: Bool) {
        if isAlreadyExport == alreadyExport {
            return
        }
        if alreadyExport {
            transition = PlayViewControllerNormalTransition()
        } else {
            transition = PlayViewControllerInterruptTransition()
        }
        
        isAlreadyExport = alreadyExport
        rightButton.isSelected = isAlreadyExport
    }
    
    func checkAlreadyExport() -> Bool {
        return isAlreadyExport
    }
    
    func popListViewAnimate() {
        
        guard let popView = popListView, popView.isHidden else {
            return
        }
        let ty: CGFloat = popView.height
        let scale: CGFloat = 0.01
        popView.transform = CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: 0, ty: ty)
        popView.isHidden = false
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 1.5, options: UIViewAnimationOptions.curveEaseInOut, animations: {
            popView.transform = CGAffineTransform.identity
        }, completion: nil)

    }
    
    private func stickerButtonDidClick() {
        showChooseSticker()
        Report.click_sticker_button()
    }
    
    private func textButtonDidClick() {
        var stickerModel: StickerModel?
        for model in StickerListManager.shared.wordStickers {
            if model.isVaild {
                stickerModel = model
                break
            }
        }
        
        if stickerModel != nil {
            if let editableSticker = try? EditBundleSticker(bundleUrl: stickerModel!.bundleUrl, startTime: videoInput.player.currentTime().seconds) {
                showArtistEditController(editableSticker)
            }
        } else {
            Hint.show(text: "当前网络不佳\n请稍后重试", center: view.center)
        }
        Report.click_huazi_button()
    }

    @IBAction func closeButtonDidClick(_ sender: UIButton) {
        transition.isInteration = false
        Report.end_edit("ClickBack", whetherSaved: completeVideoURL != nil)
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func rightButtonDidClick(_ sender: UIButton) {
        videoControl.pauseBy(.user)
        showSaveAnimateView(isAnimate: false)
        if sender.isSelected == false {
            requestAuthorizationToProcessVideo(requestHandle: {[weak self] (status) in
                if status == .authorized {
                    self?.barrageController?.barrageForLongPressToSaveNextTime()
                }
            })
            XReport.beginSaveVideo(isBeginFromClickButton: true,
                                   isVideoFromRecord: isFromRecord,
                                   filterName: backgroundFilterController?.current,
                                   videoURL: editModel.originVideoFile,
                                   stickerController: stickerController)
        } else {
            self.saveProgressView?.progress = 1
            if let videoURL = self.completeVideoURL {
                shareVideo(videoURL)
            }
        }
    }
    
    @IBAction func trimButtonDidClick(_ sender: UIButton) {
        videoControl.pauseBy(VideoControl.ControlOwner.user)
        jumpToEditTrimController()
    }
    
    @IBAction func musicButtonDidClick(_ sender: UIButton) {
        videoControl.pauseBy(VideoControl.ControlOwner.user)
        self.present(musicViewController, animated: true, completion: nil)
    }
    
    @IBAction func subtitleButtonDidClick(_ sender: UIButton) {
        if let subtitleController = voiceSubtitleManager?.tableViewController {
            videoControl.pauseBy(VideoControl.ControlOwner.user)
            self.present(subtitleController, animated: true, completion: nil)
        }
    }
    
    @IBAction func actionDeleteTemplate(_ sender: Any) {
        deleteButton.isHidden = true
        clearTemplate()
    }
    
    @IBAction func actionChangeTemplate(_ sender: Any) {
        deleteButton.isHidden = false
        changeTemplate()
    }
}

//MARK: Gestures Configure
extension PlayerViewController: PlayerGestureControllerDelegate {
    
    func configureGestureView() {
        gestureController = PlayerGestureController(contentView: guestureView)
        gestureController?.delegate = self
    }
    
    func PlayerGestureTap(point: CGPoint, sender: PlayerGestureController) {
        if isPlayerPause {
            videoControl.playBy(.user)
            Report.edit_tap_pause("play")
        } else {
            videoControl.pauseBy(.user, isPlaySound: true)
            Report.edit_tap_pause("pause")
        }
    }
    
    func PlayerGestureBeganChangeFilter(_ progress: CGFloat, sender: PlayerGestureController) {
        backgroundFilterController?.onGestureStart(atProgress: Double(progress))
        Report.filter_switch("EditPage")
    }
    
    func PlayerGestureChangingFilter(_ progress: CGFloat, sender: PlayerGestureController) {
        backgroundFilterController?.onGustureUpdate(atProgress: Double(progress))
    }
    
    func PlayerGestureEndChangeFilter(_ progress: CGFloat, sender: PlayerGestureController) {
        backgroundFilterController?.onGuestureEnd(atProgress: Double(progress))
    }
    
    func PlayerGestureBeganToPrepareSaveVideo(point: CGPoint, sender: PlayerGestureController) {
        showSaveAnimateView(isAnimate: true, animatePoint: point)
        
        debugPrint("开始准备保存视频")
    }
    
    func PlayerGestureEndSaveVideo(point: CGPoint, sender: PlayerGestureController) {
        savePrepairView?.stop()
    }
    
    func PlayerGestureCloseStart(offset: CGFloat, sender: PlayerGestureController, gesture: UIPanGestureRecognizer) {
        transition.isInteration = true
        Report.end_edit("PullDown", whetherSaved: completeVideoURL != nil)
        dismiss(animated: true, completion: nil)
        let progress = offset / guestureView.height
        transition.updateAnimate(progress)
    }
    
    func PlayerGestureClose(offset: CGFloat, sender: PlayerGestureController, gesture: UIPanGestureRecognizer) {
        let progress = offset / guestureView.height
        transition.updateAnimate(progress)
    }
    
    func PlayerGestureCloseEnd(offset: CGFloat, sender: PlayerGestureController, gesture: UIPanGestureRecognizer) {
        let progress = offset / guestureView.height
        transition.endAnimate(progress)
    }
}


//MARK: StickerView
extension PlayerViewController {
    private func configureStickerView(){
        
        let videoAsset = AVAsset(url: editModel.originVideoFile)
        
        guard let stickerViewFrame = videoAsset.videoFrameInPortraitScreen else {
            return
        }
        stickerView.frame = stickerViewFrame
        trashView.frame = stickerViewFrame
        
        stickerView.clipsToBounds = true
    }
}

//MARK: Sticker Gesture
extension PlayerViewController: PlayerStickerGestureHandlerDelegate {
    
    func configureStickerGesture() {
        stickerAction.delegate = self
    }
    
    func PlayerStickerGesturesBegin(_ gesture: UIGestureRecognizer, sticker: TransformSticker?) {
        contentView.isHidden = true
        trashView.isHidden = false
        sticker?.stickerView.alpha = 0.6
    }
    
    func PlayerStickerGesturesEnd(_ gesture: UIGestureRecognizer, sticker: TransformSticker?) {
        contentView.isHidden = false
        trashView.isHidden = true
        updateShareActionState(false)
        sticker?.stickerView.alpha = 1
    }
    
    func PlayerStickerLocationChange(_ location: CGPoint, sticker: TransformSticker?) {
    }
}

//MARK: VoiceRecognition
extension PlayerViewController: VoiceRecognitionCenterTarget, VoiceWordEditProtocol {
    func setupVoiceRecognition() {
        
        let recognitionCenter = VoiceRecognitionCenter.shared
        let result = recognitionCenter.currentResult
        
        if !isFromRecord {
            reloadVoiceRecognition()
            return
        }
        
        if result == nil {
            recognitionCenter.addTarget(self)
            voiceStateChange(.running)
        }  else {
            if result!.1 == nil {
                processVoiceRecognitionResult(result!.0)
            } else {
                processVoiceRecognitionError(result!.1!)
            }
        }
    }
    
    func processVoiceRecognitionResult(_ result: [VoiceResult]) {
        self.voiceSubtitleManager?.setSubtitleData(result)
        if(result.count > 0){
            voiceStateChange(.success)
        }else{
            voiceStateChange(.error(NSError.init(domain: "no word", code: 0, userInfo: nil)))
        }
        
        debugPrintResult(results: result)
        
        if result.count > 0 {
            let ud = UserDefaults.standard
            if !ud.bool(forKey: Constants.UdKey.hadSpeakForSubtitle) {
                ud.set(true, forKey: Constants.UdKey.hadSpeakForSubtitle)
            }
        }
    }
    
    func processVoiceRecognitionError(_ error: Error) {
        print("processVoiceRecognitionError:\(error)")
        let err = error as NSError
        if err.code == 203 {
            voiceStateChange(.timeout)
        } else {
            voiceStateChange(.error(error))
        }
    }
    
    func VoiceRecognitionDidStart() {
        
    }
    
    func VoiceRecognitionFinished(_ result: [VoiceResult], error: Error?) {
        if error != nil {
            processVoiceRecognitionError(error!)
        } else {
            processVoiceRecognitionResult(result)
        }
    }
    
    func restartVoiceRecognitionProtocol() {
        reloadVoiceRecognition()
    }
    
    private func debugPrintResult(results: [VoiceResult]) {
        #if DEBUG
            var str: String = ""
            results.forEach { (r) in
                str.append(r.text)
                str.append(Character("\n"))
            }
            print(str)
        #endif
    }
    
    private func reloadVoiceRecognition() {
        voiceStateChange(.running)
        guard let audioURL = editModel.originAudioFile else {
            let err = NSError(domain: "no voice", code: 001, userInfo: nil)
            voiceStateChange(.error(err))
            return
        }
        voiceRecognition = VoiceRecognizerReader()
        
        voiceRecognition?.read(audioURL, finished: {[weak self] (results, error) in
            if error == nil && results.count > 0 {
                self?.voiceSubtitleManager?.setSubtitleData(results)
                self?.voiceStateChange(.success)
                self?.debugPrintResult(results: results)
            } else {
                let err = error ?? NSError(domain: "no voice", code: 001, userInfo: nil)
                self?.voiceStateChange(.error(err))
            }
        })
    }
    
    private func voiceStateChange(_ state: EEVoiceSubtitleStatus) {
        switch state {
        case .running:
            let frame = CGRect.init(x: 11, y: 14, width: 18, height: 10)
            self.mixView = XHMixView(frame: frame)
            self.mixView?.isUserInteractionEnabled = false
            self.subtitleButton.addSubview(self.mixView!)
            self.subtitleButton.setImage(UIImage(named: "tirm_subtitle_bg"), for: .normal)
            self.mixView?.startAnimate(.small)
            self.voiceSubtitleManager?.setSubtitleStatus(.running)
            
        case .success:
            subtitleButton.setImage(UIImage(named: "tirm_subtitle_complete"), for: .normal)
            self.mixView?.stopAnimate()
            self.voiceSubtitleManager?.setSubtitleStatus(.success)
            changeWordOnOrOffState()
            
        case .error(let error):
            subtitleButton.setImage(UIImage.init(named: "tirm_subtitle_fail"), for: UIControlState.normal)
            mixView?.stopAnimate()
            self.voiceSubtitleManager?.setSubtitleStatus(.error(error))
        case .timeout:
            subtitleButton.setImage(UIImage.init(named: "tirm_subtitle_fail"), for: UIControlState.normal)
            mixView?.stopAnimate()
            self.voiceSubtitleManager?.setSubtitleStatus(.timeout)
        }
    }
    
    private func changeWordOnOrOffState(){
        
        if let count = voiceSubtitleManager?.tableViewController?.subtitleViewModel.wordArry.count{
            if(count <= 0){
                return
            }
        }
        
        if let powerOn = voiceSubtitleManager?.tableViewController?.subtitleViewModel.bPoweron{
            if(powerOn == true){
                subtitleButton.setImage(UIImage(named: "tirm_subtitle_complete"), for: .normal)
            }else{
                subtitleButton.setImage(UIImage(named: "tirm_subtitle_poweroff"), for: .normal)
            }
        }
    }
}

//MARK: Share
extension PlayerViewController {
    
    private func getShareViewController(_ videoURL: URL) -> UIActivityViewController {
        let activityVC = UIActivityViewController(activityItems: [videoURL], applicationActivities: nil)
        
        if let presentController: UIPopoverPresentationController = activityVC.popoverPresentationController {
            
            presentController.sourceView = contentView
            presentController.sourceRect = CGRect(x: view.centerX, y: SCREEN_HEIGHT * 0.7, width: 1, height: 1)
            presentController.permittedArrowDirections = .any
        }
        
        activityVC.excludedActivityTypes = [.saveToCameraRoll,
                                            .copyToPasteboard,
        ]
        activityVC.completionWithItemsHandler = {[weak self] type, completed, items, error in
            self?.dismissSaveAnimateView(isAnimate: true)
            self?.barrageController?.barrageForRecordAgain()
            self?.barrageController?.removeShareBarrage()
            self?.videoInput.input.resume()
            if let mType = type{
                Report.share_video(mType.rawValue)
            }
        }
        return activityVC
    }
    
    private func shareVideo(_ videoURL: URL) {
        let activityVC = getShareViewController(videoURL)
        shareVideo(activityVC: activityVC)
    }
    
    private func shareVideo(activityVC: UIActivityViewController) {
        self.present(activityVC, animated: true, completion: { [weak self] in
            self?.barrageController?.barrageForShare()
        })
    }
}
//MARK:VoiceSubtitleManager
extension PlayerViewController: SubtitleDisappearProtocol, VoiceSubtitleManagerDelegate {
    
    private func setupVoiceSubtitleController() {
        //tableviewController
        let tableViewController = SubtitleViewController()
        tableViewController.modalPresentationStyle = UIModalPresentationStyle.custom
        tableViewController.transitioningDelegate = self
        tableViewController.disappearDelegate = self
        tableViewController.voiceWordDelegate = self
        
        //manager
        voiceSubtitleManager = VoiceSubtitleManager()
        voiceSubtitleManager?.tableViewController = tableViewController
        voiceSubtitleManager?.setSubtitleStatus(.running)
        voiceSubtitleManager?.setVideoUrl(editModel.originVideoFile)
        voiceSubtitleManager?.delegate = self
        tableViewController.subtitleManager = voiceSubtitleManager
        videoControl.addTarget(voiceSubtitleManager!)
    }
    
    func subtitleDisappearProtocol(){
        updateShareActionState(false)
        changeWordOnOrOffState()
        playerBackToZero()
        DispatchQueue.main.async {[weak self] in
            self?.videoControl.playBy(VideoControl.ControlOwner.user)
        }
    }
    
    func VoiceSubtitleDidClick(_ subtitle: VoiceSubtitleModel, sender: VoiceSubtitleManager) {
        if let subtitleVC = sender.tableViewController {
            videoControl.pauseBy(VideoControl.ControlOwner.user)
            present(subtitleVC, animated: true, completion: {
                sender.tableViewController?.scrollToSubtitle(subtitle.guidNumber)
            })
        }
    }
}

//MARK: Setup sticker
extension PlayerViewController: StickerControllerDelegate {

    private func setupSticker() {
        videoControl.addTarget(stickerRender)
        
        stickerController = StickerController(forView: stickerView, andRender: stickerRender, andVideoControl: videoControl, andAudioCenter: audioCenter)
        stickerController.delegate = self
    }
    
    private func addDefaultStickers() {
        //Add watermark
        if let watermark = createWatermarkSticker() {
            stickerController.add(sticker: watermark)
        }
        
        if let subtitleSticker = self.voiceSubtitleManager {
            stickerController.add(sticker: subtitleSticker)
        }
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()+0.3) {[weak self] in
            self?.createResidentSticker()
        }
    }
    
    private func buildRenderForExport() -> (UIView, Render,AudioExporter) {
        let stickerRenderView = UIView(frame: CGRect(x: 0, y: 0, width: stickerView.frame.width, height: stickerView.frame.height))
        let stickerRender = Render()
        let renderStickers = stickerController.buildRenderStickers()
        var audioRenders = [AudioRender]()
        for sticker in renderStickers {
            let context = StickerContextImpl()
            sticker.stickerContext = context
            sticker.initView(inFatherView: stickerRenderView)
            stickerRender.addComponent(sticker.controller)
            
            if let audioRenderable = sticker as? AudioRenderable, let audioRender = audioRenderable.audioRender {
                audioRenders.append(audioRender)
            }
        }
        let bgmController = BGMController(forAudioFileURL: audioCenter.bgmController.audioURL, andBGMFile: audioCenter.bgmController.bgmURL)
        bgmController.balance = audioCenter.bgmController.balance
        bgmController.bgmStartTime = audioCenter.bgmController.bgmStartTime
        audioRenders.append(bgmController)
        let audioExporter = AudioExporter(forRenders: audioRenders)
        return (stickerRenderView, stickerRender, audioExporter)
    }
    
    private func createResidentSticker(){
        let pinId = GetStickerResidentID()
        guard let stickerModel = StickerListManager.shared.stickerCache[pinId] else {
            return
        }
        do {
            let sticker = try createSticker(stickerModel)
            SVProgressHUD.setDefaultMaskType(SVProgressHUDMaskType.clear)
            SVProgressHUD.show()
            sticker.prepareToShow {[weak self] error in
                SVProgressHUD.dismiss()
                if let err = error {
                    if(stickerErrorIsHandled(err) == false){
                        SVProgressHUD.showError(withStatus: err.localizedDescription)
                        SVProgressHUD.dismiss(withDelay: 0.5)
                    }
                } else {
                    sticker.trackEnabled = false
                    self?.stickerController.add(sticker: sticker)
                }
            }
        } catch {
            print(error)
        }
    }
    
    private func createWatermarkSticker() -> EditBundleSticker? {
        guard let stickerModel = getCurrentWatermarkModel() else {
            return nil
        }
        do {
            let sticker = try createSticker(stickerModel)
            sticker.rootView.isHidden = true
            sticker.rootView.isUserInteractionEnabled = false
            sticker.prepareToShow(complete: nil)
            return sticker
        } catch {
            print(error)
            return nil
        }
    }
    
    private func getCurrentWatermarkModel() -> StickerModel? {
        let watermarkId = UserDefaults.standard.integer(forKey: Constants.UdKey.selectWatermarkId)
        if watermarkId >= 0 {
            for model in StickerListManager.shared.watermarkStickers {
                if model.resource.id == watermarkId {
                    return model
                }
            }
        }
        return nil
    }
    
    private func createSticker(_ model: StickerModel, startTime: TimeInterval = 0) throws -> EditBundleSticker {
        let sticker = try PlayerBundleSticker(bundleUrl: model.bundleUrl, startTime: startTime)
        sticker.boardController?.isHidden = true
        let context = StickerContextImpl(gestureDelegate:stickerAction, editableStickerDelegate: self, stickerController: nil, videoControl: videoControl, stickerRender: stickerRender, editModel: editModel, trackLoadingControl: self)
        sticker.stickerContext = context
        return sticker
    }
    
    func StickerControllerCountChanged(_ sender: StickerController) {
        DispatchQueue.main.async { [weak self] in
            self?.updateShareActionState(false)
        }
    }
}

//MARK: StickerWebControllerDelegate
extension PlayerViewController : StickerWebControllerDelegate {
    
    func checkChangedResidentSticker() -> Bool {
        let changedKey = Constants.UdKey.hadChangedResidentSticker
        let ud = UserDefaults.standard
        let resultBool = ud.bool(forKey: changedKey)
        return resultBool
    }
    
    func updateChangedResidentSticker(){
        let changedKey = Constants.UdKey.hadChangedResidentSticker
        let ud = UserDefaults.standard
        ud.set(false, forKey: changedKey)
    }
    
    func addStickerDelegate(_ sticker: ViewSticker) {
        if let playerSticker = sticker as? PlayerBundleSticker {
            stickerController.add(sticker: playerSticker)
            
            if let trackView = playerSticker.trackView{
                if(trackView.isTrack){
                    if(checkAutoStickerGuaidVC()){
                        if(checkChangedResidentSticker()){
                            hintForStickerWithMessage(playerSticker.stickerView.y,centerX: playerSticker.stickerView.x + playerSticker.stickerView.middleX,message: "下次将自动添加")
                            updateChangedResidentSticker()
                        }else{
                            hintForStickerWithMessage(playerSticker.stickerView.y,centerX: playerSticker.stickerView.x + playerSticker.stickerView.middleX, message: "拖动到目标上")
                        }
                        
                    }else{
                        setupAutoTrackGuideView()
                        hintTopY = playerSticker.stickerView.y
                        hintCenterX = playerSticker.stickerView.x + playerSticker.stickerView.middleX
                        if(checkChangedResidentSticker()){
                            hintMessage = "下次将自动添加"
                            updateChangedResidentSticker()
                        }else{
                            hintMessage = "拖动到目标上"
                        }
                    }
                }else{
                    if(checkChangedResidentSticker()){
                        hintForStickerWithMessage(playerSticker.stickerView.y,centerX: playerSticker.stickerView.x + playerSticker.stickerView.middleX, message: "下次将自动添加")
                        updateChangedResidentSticker()
                    }
                }
            }else{
                if(checkChangedResidentSticker()){
                    hintForStickerWithMessage(playerSticker.stickerView.y,centerX: playerSticker.stickerView.x + playerSticker.stickerView.middleX, message: "下次将自动添加")
                    updateChangedResidentSticker()
                }
            }
        }
    }
    
    private func setupStickerWebController(){
        stickerWebController = StickerWebViewController()
        stickerWebController.modalPresentationStyle = .custom
        stickerWebController.transitioningDelegate = self
        stickerWebController.stickerDelegate = self
    }
    
    private func hintForStickerWithMessage(_ stickerY: CGFloat ,centerX:CGFloat , message:String) {
        let hintLabel = UILabel()
        hintLabel.text = message
        hintLabel.font = UIFont.boldSystemFont(ofSize: 18)
        hintLabel.textColor = UIColor.white
        hintLabel.backgroundColor = UIColor.clear
        hintLabel.layer.shadowOffset = CGSize(width: 0, height: 2)
        hintLabel.layer.shadowRadius = 10
        hintLabel.layer.shadowColor = UIColorFromRGBA(0, g: 0, b: 0, a: 0.5).cgColor
        hintLabel.layer.shadowOpacity = 1
        hintLabel.sizeToFit()
        let x = (stickerView.width - hintLabel.width) * 0.5
        let hintBottomToSticker: CGFloat = 10
        let y = stickerY - hintBottomToSticker - hintLabel.height
        let point = CGPoint(x: x, y: y)
        hintLabel.frame = CGRect(origin: point, size: hintLabel.frame.size)
        hintLabel.centerX = centerX
        stickerView.addSubview(hintLabel)
        hintLabel.fadeOut(duration: 0.5, delay: 1.5) {
            hintLabel.removeFromSuperview()
        }
    }
}

//MARK:ArtistViewController
extension PlayerViewController: ArtistEditProtocol {
    
    func showArtistEditController(_ sticker: ArtistEditViewController.EditSticker){
        contentView.isHidden = true
        let artistEdit = ArtistEditViewController()
        artistEdit.editDelegate = self
        artistEdit.editSticker = sticker
        artistEdit.modalPresentationStyle = UIModalPresentationStyle.custom
        artistEdit.transitioningDelegate = artistEdit
        self.present(artistEdit, animated: true, completion: nil)
    }
    
    func endEditSticker(_ editSticker : ArtistEditViewController.EditSticker) {
        contentView.isHidden = false
        if let editable = editSticker as? EditableSticker & BundleSticker {
            if let playerSticker = PlayerBundleSticker(from: editable) {
                let context = StickerContextImpl(gestureDelegate: stickerAction, editableStickerDelegate: self, stickerController: nil, videoControl: videoControl, stickerRender: stickerRender, editModel: editModel, trackLoadingControl: self)
                playerSticker.stickerContext = context
                playerSticker.prepareToShow(complete: nil) //should be prepared
                stickerController.add(sticker: playerSticker)
                
                if let trackView = playerSticker.trackView{
                    if(trackView.isTrack){
                        if(checkAutoStickerGuaidVC()){
                            hintForStickerWithMessage(playerSticker.stickerView.y,centerX: playerSticker.stickerView.x + playerSticker.stickerView.middleX,message: "拖动到目标上")
                        }else{
                            setupAutoTrackGuideView()
                            hintTopY = playerSticker.stickerView.y
                            hintCenterX = playerSticker.stickerView.x + playerSticker.stickerView.middleX
                            hintMessage = "拖动到目标上"
                        }
                    }
                }
            }
        }
        
    }
    
    private func showChooseSticker() {
        let context = StickerContextImpl(gestureDelegate: stickerAction, editableStickerDelegate: self, stickerController: stickerController, videoControl: videoControl, stickerRender: stickerRender, editModel: editModel, trackLoadingControl: self)
        stickerWebController.stickerContext = context
        stickerWebController.startTime = videoInput.input.player.currentTime().seconds
        self.present(stickerWebController, animated: true, completion: nil)
    }

}

//MARK: -
//MARK: Editable
extension PlayerViewController: EditableStickerDelegate {
    
    func startEditMode(forEditable: EditableStickerBuilder) {
        if let editableSticker = forEditable.buildEditableSticker() as? ArtistEditViewController.EditSticker {
            showArtistEditController(editableSticker)
        }
        if let origin = forEditable as? RuntimeLoadableSticker {
            stickerController.remove(sticker: origin)
        }
    }
}


//MARK: Barrage
extension PlayerViewController {
    func setupBarrage() {
        barrageController = PlayerVCBarrageCenter(contentView: guideView)
    }
}

extension PlayerViewController{
    func playPauseSound(){
        DispatchQueue.main.async {
            XHPlaySound.shared.playSound(name: "pause.wav")
        }
    }
}

//MARK:IphoneX
extension PlayerViewController{
    func changeLayoutConstraint(){
        if(isScreenX()){
            closeTop.constant = 44
            rightTop.constant = 44
            let iPhoneXBottomOffset: CGFloat = 34
            bottomBlackHeight.constant += iPhoneXBottomOffset
            bottomSliderView?.y -= iPhoneXBottomOffset
            popListView?.y -= iPhoneXBottomOffset
        }
    }
}
//MARK:Music
extension PlayerViewController:MusicControllerDelegate{
    
    func setupMusicController(){
        musicViewController = MusicViewController()
        musicViewController.modalPresentationStyle = .custom
        musicViewController.transitioningDelegate = self
        musicViewController.soundURL = editModel.originAudioFile
        musicViewController.musicDelegate = self
    }
    
    func changeMusicWithURL(_ musicURL: URL?, point: CGPoint){
        playerBackToZero()
        
        var audio :Double = Double(point.y)
        audioCenter.bgmController.changeBGM(to: musicURL)
        
        if(musicURL == nil){
            audio = 1.0
        }
        audioCenter.bgmController.balance = Double(audio)
        DispatchQueue.main.async {[weak self] in
            self?.videoControl.playBy(VideoControl.ControlOwner.user)
        }
        updateShareActionState(false)
    }
}

//MARK: RangeControl
extension PlayerViewController: PlayerViewRangeControlDelegate {
    
    func setupRangeControl() {
        rangeControl = PlayerViewRangeControl()
        rangeControl?.delegate = self
    }
    
    func changeRange(lower: Double, upper: Double) {
        rangeControl?.lower = lower
        rangeControl?.upper = upper
        rangeControl?.seekAt(rangeProgress: 0)
        updateSliderProgress(0)
        audioCenter.bgmController.bgmStartTime = CMTime(seconds: videoDuration * lower, preferredTimescale: CMTimeScale(1000))
    }
    
    func getCMTimeRangeFromRangeControl() -> CMTimeRange {
        let duration = AVAsset(url: editModel.originVideoFile).duration
        let startProgress = rangeControl?.lower ?? 0
        let endProgress = rangeControl?.upper ?? 0
        let startSecond = startProgress * duration.seconds
        let endSecond = endProgress * duration.seconds
        let startTime = CMTime(seconds: startSecond, preferredTimescale: duration.timescale)
        let endTime = CMTime(seconds: endSecond, preferredTimescale: duration.timescale)
        let timeRange = CMTimeRange(start: startTime, end: endTime)
        return timeRange
    }

    func RangeControlChanged(rangeProgress: Double, sender: PlayerViewRangeControl) {
        updateSliderProgress(rangeProgress)
    }
    
    func RangeControlDidEndToUpper(_ sender: PlayerViewRangeControl) {
        videoControl.pauseBy(.player)
        playerBackToZero()
    }
    
    func RangeControlShouldSeek(atRealProgess: Double, sender: PlayerViewRangeControl) {
        let time = videoDuration * atRealProgess
        videoControl.progressBeganToChange(.engineer, progress: atRealProgess, time: time, duration: videoDuration)
        videoControl.progressChangeBy(.engineer, progress: atRealProgess, time: time, duration: videoDuration)
        videoControl.progressEndChange(.engineer, progress: atRealProgess, time: time, duration: videoDuration)
    }
}

extension PlayerViewController: EditTrimDelegate {
    
    private func createTrimModel() -> EditTrimModel{
        var startSecond = 0.0
        var endSecond = 10.0
        
        if let controlRange = rangeControl{
            if(changedRange == true){
                startSecond = controlRange.lower * videoDuration
                endSecond = controlRange.upper * videoDuration
            }
        }
        if(endSecond > videoDuration){
            endSecond = videoDuration
        }
        
        let videoRange = CMTimeRange(start: CMTime(seconds: startSecond, preferredTimescale: 600) , end: CMTime(seconds: endSecond, preferredTimescale: 600))
        
        let trimModel = EditTrimModel(videoURL: editModel.originVideoFile, audioURL: editModel.originAudioFile, range: videoRange)
        return trimModel
    }
    
    private func jumpToEditTrimController(){
        
        let videoStoryBoard = UIStoryboard(name: "Video", bundle: Bundle.main)
        
        let dest:EditTrimViewController = videoStoryBoard.instantiateViewController(withIdentifier: "editTrimViewController") as! EditTrimViewController
        dest.bgImage = getCurrentImage()
        dest.trimModel = createTrimModel()
        dest.trimDelegate = self
        dest.transitioningDelegate = trimTransition
        
        self.present(dest, animated: true, completion: nil)
    }
    
    func changToRange(_ range: CMTimeRange) {
        let lower = range.start.seconds / videoDuration
        let upper = range.end.seconds / videoDuration
        changeRange(lower: lower, upper: upper)
        changedRange = true
        playerBackToZero()
        DispatchQueue.main.async {[weak self] in
            self?.videoControl.playBy(VideoControl.ControlOwner.user)
        }
    }
    
    func getCurrentImage() -> UIImage? {
        let time = Double(bottomSliderView?.progress ?? 0) * videoDuration
        let image = AVAsset(url: editModel.originVideoFile).getImage(time: time)
        return image
    }
}
extension PlayerViewController{
    private func setupCurrentlabel(){
        if(currentLabelView != nil){
            return
        }
        let viewTemp = Bundle.main.loadNibNamed("CurrentTimeView", owner: nil, options: nil)
        if let view = viewTemp?.first as? CurrentTimeView{
            currentLabelView = view
            var height : CGFloat = 160
            if(isScreenX()){
                height = 160 + 44
            }
            //currentLabelView.frame = CGRect(x: 0, y: 0, width:UIScreen.main.bounds.size.width , height: height)
            contentView.addSubview(currentLabelView)
            currentLabelView.translatesAutoresizingMaskIntoConstraints  = false
            currentLabelView.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
            currentLabelView.leftAnchor.constraint(equalTo: contentView.leftAnchor).isActive = true
            currentLabelView.rightAnchor.constraint(equalTo: contentView.rightAnchor).isActive = true
            currentLabelView.heightAnchor.constraint(equalToConstant: height).isActive = true
            currentLabelView.isHidden = true
        }
    }
    
    private func beginShowCurrentTimeView(_ progress:Double){
        currentLabelView.isHidden = false
        currentLabelView.setDurationTime(getDuration())
        currentLabelView.setCurrentTime(getTimeStringFromSecond(progress))
    }
    
    private func showCurrentTime(_ progress:Double){
        currentLabelView.setCurrentTime(getTimeStringFromSecond(progress))
    }
    private func hideCurrentTimeView(){
        currentLabelView.isHidden = true
    }
    
    private func getDuration()-> String{
        
        var duration = videoDuration
        
        if let mControl = rangeControl{
            duration = (mControl.upper - mControl.lower) * videoDuration
        }
        return getTimeStringFromSecond(duration)
    }
}

//MARK: VideoGuide
extension PlayerViewController: PlayerVCPlayerGuideDelegate {
    
    func configureVideoGuide() {
        if checkPlayVideoGuide() {
            addPlayerVideoGuide()
        }
    }
    
    func checkPlayVideoGuide() -> Bool {
        let ud = UserDefaults.standard
        let key = Constants.UdKey.displayPlayerVideoGuide
        return !ud.bool(forKey: key)
    }
    
    func addPlayerVideoGuide() {
        if playerGuideVC != nil {
            return
        }
        let vc = PlayerVCPlayerGuideController(autoTrackGuide: false)
        vc.delegate = self
        vc.view.frame = view.bounds
        view.addSubview(vc.view)
        vc.play()
        vc.displayCloseBtn(delay: 3)
        playerGuideVC = vc
        contentView.isHidden = true
    }
    
    func PlayerVCPlayerGuideDidClosed(_ autoStickerGuide:Bool) {
        if(autoStickerGuide == false){
            UserDefaults.standard.set(true, forKey: Constants.UdKey.displayPlayerVideoGuide)
            videoControl.playBy(.engineer)
            playerGuideVC = nil
        }else{
            UserDefaults.standard.set(true, forKey: Constants.UdKey.autoTrackStickerVideoGuide)
            autoStickerGuaidVC = nil
            hintForStickerWithMessage(hintTopY,centerX: hintCenterX,message: hintMessage)
            isShowingAutoTrackVideo = false
        }
        contentView.isHidden = false
    }
    
    func checkAutoStickerGuaidVC()->Bool{
        let ud = UserDefaults.standard
        let key = Constants.UdKey.autoTrackStickerVideoGuide
        return ud.bool(forKey: key)
    }
    
    func setupAutoTrackGuideView(){
        if(checkAutoStickerGuaidVC() == true){
            return
        }
        let vc = PlayerVCPlayerGuideController(autoTrackGuide: true)
        vc.delegate = self
        vc.view.frame = view.bounds
        view.addSubview(vc.view)
        vc.play()
        vc.displayCloseBtn(delay: 3)
        autoStickerGuaidVC = vc
        isShowingAutoTrackVideo = true
        contentView.isHidden = true
        
    }
}

extension PlayerViewController: TrackLoadingControl {
    func setupTracker() {
        trackersCenter = StickerTrackerCenter()
        trackersCenter.lastImage = getFirstTrackerImage()
        videoInput.add(target: trackersCenter.output)
        videoControl.addTarget(trackersCenter)
        StickerTrackerCenter.current = trackersCenter
        initTrackLoadingView()
    }
    
    private func initTrackLoadingView() {
        if let view = Bundle.main.loadNibNamed("TrackLoadingView", owner: nil, options: nil)?.first as? UIView {
            trackLoadingView = view
        }
        
    }
    
    func showTrackLoading() {
        trackLoadingViewShowCount += 1
        if trackLoadingViewShowCount == 1 {
            saveView.addSubview(trackLoadingView)
            trackLoadingView.translatesAutoresizingMaskIntoConstraints = false
            trackLoadingView.leftAnchor.constraint(equalTo: saveView.leftAnchor).isActive = true
            trackLoadingView.rightAnchor.constraint(equalTo: saveView.rightAnchor).isActive = true
            trackLoadingView.topAnchor.constraint(equalTo: saveView.topAnchor).isActive = true
            trackLoadingView.bottomAnchor.constraint(equalTo: saveView.bottomAnchor).isActive = true
            if let lottieView = trackLoadingView.viewWithTag(10086) as? LottieView {
                lottieView.play()
            }
        }
    }
    
    func hideTrackLoading() {
        trackLoadingViewShowCount -= 1
        if trackLoadingViewShowCount == 0 {
            trackLoadingView.removeFromSuperview()
            if let lottieView = trackLoadingView.viewWithTag(10086) as? LottieView {
                lottieView.stop()
            }
            videoControl.playBy(.user)
        }
    }
    
    private func getFirstTrackerImage() -> CGImage? {
        guard let image = backgroundImageView.image else {
            return nil
        }
        
        return image.cgImage
    }
    
    @objc func trackStateDidChanged(_ notifi: Notification) {
        guard let _ = notifi.userInfo?["isTrack"] as? Bool else {
            return
        }
        
        guard let sticker = notifi.object as? RenderBundleSticker else {
            return
        }
        
        if let tracking:Bool = notifi.userInfo?["isTrack"] as? Bool{
            
            if(!tracking){
                hintForStickerWithMessage(sticker.stickerView.y,centerX: sticker.stickerView.x + sticker.stickerView.middleX, message: "贴纸跟踪关闭")
                
            }else{
                hintForStickerWithMessage(sticker.stickerView.y,centerX: sticker.stickerView.x + sticker.stickerView.middleX ,message: "贴纸跟踪开启")
            }
        }
    }
}

extension PlayerViewController: TemplateManagerDelegate {
    func configureTemplate() {
        templateManager = TemplateManager()
        templateManager?.bgFilterController = backgroundFilterController
        templateManager?.stickerController = stickerController
        templateManager?.delegate = self
    }
    
    func clearTemplate() {
        templateManager?.clearTemplate()
    }
    
    func changeTemplate() {
        isTemplateChanging = true
        videoControl.pauseBy(.engineer)
        SVProgressHUD.setDefaultMaskType(.black)
        SVProgressHUD.show()
        templateManager?.changeTemplate()
    }
    
    func TemplateManagerGetSticker(_ stickerModel: StickerModel, startTime: Double) -> EditBundleSticker? {
        return try? createSticker(stickerModel, startTime: startTime)
    }
    
    func TemplateManagerDidChanged(_ error: Error?) {
        SVProgressHUD.dismiss()
        
        if error != nil {
            #if DEBUG
                Hint.show(text: "\(error!)", center: view.center)
            #else
                Hint.show(text: "网络连接慢，智能后期啦~", center: view.center)
            #endif
            return
        } else {
            playerBackToZero()
        }
        DispatchQueue.main.async {[weak self] in
            self?.videoControl.playBy(VideoControl.ControlOwner.engineer)
        }
        isTemplateChanging = false
    }
}

