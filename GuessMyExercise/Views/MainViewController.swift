/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The app's main view controller.
*/

import UIKit
import Vision

let localData = UserDefaults.standard

@available(iOS 14.0, *)
class MainViewController: UIViewController {
    /// 显示视频帧顶部姿势的全屏视图
    @IBOutlet var imageView: UIImageView!

    /// 在前缘中间包含标签的堆栈
    @IBOutlet weak var labelStack: UIStackView!

    /// 显示模型的运动动作预测的标签。
    @IBOutlet weak var actionLabel: UILabel!

    /// 显示模型对预测的信心的标签。
    @IBOutlet weak var confidenceLabel: UILabel!

    /// 在前缘底部包含按钮的堆栈。
    @IBOutlet weak var buttonStack: UIStackView!

    /// 用户点击按钮显示摘要视图
    @IBOutlet weak var summaryButton: UIButton!
    
    /// 输入api按钮
    @IBOutlet weak var apiButton: UIButton!

    /// 用户点击该按钮可在正面和背面之间切换
    /// cameras.
    @IBOutlet weak var cameraButton: UIButton!

    /// 从相机捕获帧并创建帧发布器
    var videoCapture: VideoCapture!

    /// 从框架发布服务器构建联合发布服务器链。
    ///
    /// 视频处理链为视图控制器提供:
    /// - 每个摄像机帧都是一个“CGImage”。
    /// - 在那一帧中观察到的任何人的“视觉”的“姿势”数组。
    /// - 随着时间的推移，突出人物姿势的动作预测。
    var videoProcessingChain: VideoProcessingChain!

    /// 维护模型预测的每个操作的聚合时间。
    /// - Tag: actionFrameCounts
    var actionFrameCounts = [String: Int]()
}

// MARK: - View Controller Events
extension MainViewController {
    /// 在主视图加载后配置它。
    override func viewDidLoad() {
        super.viewDidLoad()

        // 禁用空闲计时器以防止屏幕锁定。
        UIApplication.shared.isIdleTimerDisabled = true

        // 堆栈和按钮视图的圆角。
        let views = [labelStack, buttonStack, cameraButton, summaryButton, apiButton]
        views.forEach { view in
            view?.layer.cornerRadius = 10
            view?.overrideUserInterfaceStyle = .dark
        }

        // 将视图控制器设置为视频处理链的代理。
        videoProcessingChain = VideoProcessingChain()
        videoProcessingChain.delegate = self

        // 开始从视频捕获接收帧。
        videoCapture = VideoCapture()
        videoCapture.delegate = self

        updateUILabelsWithPrediction(.startingPrediction)
    }

    /// 使用设备的方向配置视频捕获会话
    ///
    /// 这是该应用程序第一个利用硬件传感器获取设备的物理方位
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // 更新设备的方向。
        videoCapture.updateDeviceOrientation()
    }

    /// 当设备旋转到新方向时通知视频捕获。
    override func viewWillTransition(to size: CGSize,
                                     with coordinator: UIViewControllerTransitionCoordinator) {
        // 更新相机的方向以匹配设备的方向
        videoCapture.updateDeviceOrientation()
    }
}

// MARK: - Button Events
extension MainViewController {
    /// 在前置和后置摄像头之间切换视频捕获。
    @IBAction func onCameraButtonTapped(_: Any) {
        videoCapture.toggleCameraSelection()
    }

    /// 显示用户操作及其总时间的摘要视图。
    @IBAction func onSummaryButtonTapped() {
        let main = UIStoryboard(name: "Main", bundle: nil)

        // 根据视图控制器的名称获取视图控制器。
        let vcName = "SummaryViewController"
        let viewController = main.instantiateViewController(identifier: vcName)

        // 将其转换为“SummaryViewController”。
        guard let summaryVC = viewController as? SummaryViewController else {
            fatalError("Couldn't cast the Summary View Controller.")
        }

        // 将当前操作时间复制到摘要视图。
        summaryVC.actionFrameCounts = actionFrameCounts

        // 定义摘要视图的显示样式。
        modalPresentationStyle = .popover
        modalTransitionStyle = .coverVertical

        // 当用户取消摘要视图时，重新建立视频处理链。
        summaryVC.dismissalClosure = {
            // 当摘要视图消失时，通过启用相机恢复视频馈送。
            self.videoCapture.isEnabled = true
        }

        // 向用户显示摘要视图。
        present(summaryVC, animated: true)

        // 通过在显示摘要视图时禁用相机来停止视频馈送。
        videoCapture.isEnabled = false
    }
    
    //本地保存api地址按钮
    @IBAction func onApiButtonTapped(_: Any) {
        
        let alertController = UIAlertController(title: "设置API",
                                    message: "", preferredStyle: .alert)
        alertController.addTextField {
            (textField: UITextField!) -> Void in
            textField.placeholder = "请输入API"
        }
        let cancelAction = UIAlertAction(title: "取消", style: .cancel, handler: nil)
        let okAction = UIAlertAction(title: "保存", style: .default, handler: {
            action in
            //也可以用下标的形式获取textField let login = alertController.textFields![0]
            let apiData = alertController.textFields!.first!
            let fullStr = apiData.text! as NSString
            //print("api url：\(fullStr)")
            localData.setValue(fullStr, forKey: "apiUrl")
        })
        alertController.addAction(cancelAction)
        alertController.addAction(okAction)
        self.present(alertController, animated: true, completion: nil)
        
    }
    
}



// MARK: - Video Capture Delegate
extension MainViewController: VideoCaptureDelegate {
    /// 从视频捕获接收视频帧发布者。
    /// - Parameters:
    ///   - videoCapture: A `VideoCapture` 实例.
    ///   - framePublisher: 视频捕获中的新帧发布者
    func videoCapture(_ videoCapture: VideoCapture,
                      didCreate framePublisher: FramePublisher) {
        updateUILabelsWithPrediction(.startingPrediction)
        
        // 通过分配新的帧发布器来构建新的视频处理链。
        videoProcessingChain.upstreamFramePublisher = framePublisher
    }
}

// MARK: - video-processing chain Delegate
extension MainViewController: VideoProcessingChainDelegate {
    /// 从视频处理链接收动作预测。
    /// - Parameters:
    ///   - chain: 视频处理链.
    ///   - actionPrediction: 行动预测。
    ///   - duration: 预测所代表的时间跨度。
    /// - Tag: detectedAction
    func videoProcessingChain(_ chain: VideoProcessingChain,
                              didPredict actionPrediction: ActionPrediction,
                              for frameCount: Int) {

        if actionPrediction.isModelLabel {
            // 更新此操作的总帧数。
            addFrameCount(frameCount, to: actionPrediction.label)
        }

        // 在UI中显示预测。
        updateUILabelsWithPrediction(actionPrediction)
    }

    /// 接收一帧和该帧中的任何姿势。
    /// - Parameters:
    ///   - chain: 视频处理链。
    ///   - poses: “姿势”数组。
    ///   - frame: 作为“CGImage”的视频帧。
    func videoProcessingChain(_ chain: VideoProcessingChain,
                              didDetect poses: [Pose]?,
                              in frame: CGImage) {
        // 在与pose publisher不同的队列上渲染pose。
        DispatchQueue.global(qos: .userInteractive).async {
            
            //if poseArray.count < 2 {
                //获取的数据转换为json
                poseArrayToJsonList(poses)
            //}
            // 把姿势画到框架上
            self.drawPoses(poses, onto: frame)
        }
    }
}

//遍历pose数组
private func poseArrayToJsonList(_ poses: [Pose]?){
    guard let poses = poses else { return }
    
    //获取的pose数据转换为 json array
    var poseArray = [String]()
    
    for poseItem in poses {
        let landmarkList = poseItem.landmarks
        for item in landmarkList {
            let itemData = item
            
            guard let jsonData = try? JSONSerialization.data(withJSONObject: itemData.plDectionary, options: .prettyPrinted) else { return }
            
            guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }
            
            poseArray.append(jsonString);
            //print("item json = \(jsonString)")
        }
    }
    //print("item json = \(poseArray)")
    requestHttpServer(poseArray)
}

//访问http api -- 未完成
func requestHttpServer (_ jsonString: [String]) {
    
    let apiUrl = localData.string(forKey: "apiUrl")! as NSString
    
    //let apiUrl = "http://192.168.3.121:3002/api/detectionpose"
    
    if(apiUrl.length == 0 || apiUrl == "zccv" || jsonString.count == 0 || jsonString.isEmpty){
        return
    }
    
    let url = URL(string: apiUrl as String)
    var request = URLRequest(url: url!)
    request.httpMethod = "POST"
    
    //print("apiUrl = \(apiUrl)")
    //print("body = \(body)")
    
    let params = ["poseData": jsonString]

    request.httpBody = try! JSONSerialization.data(withJSONObject: params, options: [])
    request.addValue("application/json", forHTTPHeaderField:"Content-Type")
    request.addValue("application/json", forHTTPHeaderField:"Accept")
    
    NSURLConnection.sendAsynchronousRequest(request, queue: OperationQueue.main) {(response, data, error) in
        guard let data = data else { return }
        print(String(data: data, encoding: .utf8)!)
    }
    
}



// MARK: - Helper methods
extension MainViewController {
    /// 将增量持续时间添加到操作的总时间中。
    /// - Parameters:
    ///   - actionLabel: 操作的名称。
    ///   - duration: 操作的增量持续时间。
    private func addFrameCount(_ frameCount: Int, to actionLabel: String) {
        // 将新的持续时间添加到当前总计（如果存在）。
        let totalFrames = (actionFrameCounts[actionLabel] ?? 0) + frameCount

        // 为此操作指定新的总帧计数。
        actionFrameCounts[actionLabel] = totalFrames
    }

    /// 使用预测及其可信度更新用户界面的标签。
    /// - Parameters:
    ///   - label: 预测标签.
    ///   - confidence: 预测的置信值
    private func updateUILabelsWithPrediction(_ prediction: ActionPrediction) {
        // 在主线程上更新UI的预测标签。
        DispatchQueue.main.async { self.actionLabel.text = prediction.label }

        // 在主线程上更新UI的置信度标签。
        let confidenceString = prediction.confidenceString ?? "Observing..."
        DispatchQueue.main.async { self.confidenceLabel.text = confidenceString }
    }

    /// 将姿势绘制为帧顶部的线框，并使用最终图像更新用户界面。
    /// - Parameters:
    ///   - poses: An array of human body poses.
    ///   - frame: An image.
    /// - Tag: drawPoses
    private func drawPoses(_ poses: [Pose]?, onto frame: CGImage) {
        // 以1:1的比例创建默认渲染格式。
        let renderFormat = UIGraphicsImageRendererFormat()
        renderFormat.scale = 1.0

        // 创建与帧大小相同的渲染器。
        let frameSize = CGSize(width: frame.width, height: frame.height)
        let poseRenderer = UIGraphicsImageRenderer(size: frameSize,
                                                   format: renderFormat)

        // 首先绘制帧，然后在其上绘制姿势线框。
        let frameWithPosesRendering = poseRenderer.image { rendererContext in
            // “UIGraphicsSimageRender”实例会翻转Y轴，假设我们正在使用UIKit的坐标系和方向绘制。
            let cgContext = rendererContext.cgContext

            // 得到电流变换矩阵的逆矩阵。
            let inverse = cgContext.ctm.inverted()

            // 通过将CTM乘以其逆值来恢复Y轴，从而将上下文的变换矩阵重置为恒等式。
            cgContext.concatenate(inverse)

            // 首先绘制相机图像作为背景。
            let imageRectangle = CGRect(origin: .zero, size: frameSize)
            cgContext.draw(frame, in: imageRectangle)

            // 创建一个变换，将姿势的标准化点坐标`[0.0，1.0]`转换为适合帧的大小。
            let pointTransform = CGAffineTransform(scaleX: frameSize.width,
                                                   y: frameSize.height)

            guard let poses = poses else { return }

            // 绘制框架中的所有姿势。
            for pose in poses {
                // 以图像的比例将每个姿势绘制为线框。
                pose.drawWireframeToContext(cgContext, applying: pointTransform)
            }
        }

        // 在主线程上更新UI的全屏图像视图。
        DispatchQueue.main.async { self.imageView.image = frameWithPosesRendering }
    }
}
