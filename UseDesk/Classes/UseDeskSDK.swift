//
//  UseDeskSDK.swift

import Foundation
import SocketIO
import MBProgressHUD
import Alamofire
import UserNotifications

public typealias UDSStartBlock = (Bool, String?) -> Void
public typealias UDSBaseBlock = (Bool, [BaseCollection]?, String?) -> Void
public typealias UDSArticleBlock = (Bool, Article?, String?) -> Void
public typealias UDSArticleSearchBlock = (Bool, SearchArticle?, String?) -> Void
public typealias UDSConnectBlock = (Bool, String?) -> Void
public typealias UDSNewMessageBlock = (Bool, RCMessage?) -> Void
public typealias UDSErrorBlock = ([Any]?) -> Void
public typealias UDSFeedbackMessageBlock = (RCMessage?) -> Void
public typealias UDSFeedbackAnswerMessageBlock = (Bool) -> Void

let RootView = UIApplication.shared.keyWindow?.rootViewController

public class UseDeskSDK: NSObject {
    public var newMessageBlock: UDSNewMessageBlock?
    public var connectBlock: UDSConnectBlock?
    public var errorBlock: UDSErrorBlock?
    public var feedbackMessageBlock: UDSFeedbackMessageBlock?
    public var feedbackAnswerMessageBlock: UDSFeedbackAnswerMessageBlock?
    public var historyMess: [AnyHashable] = []
    
    var manager: SocketManager?
    var socket: SocketIOClient?
    var companyID = ""
    var email = ""
    var phone = ""
    var url = ""
    var urlWithoutPort = ""
    var token = ""
    var account_id = ""
    var api_token = ""
    var port = ""
    var name = ""
    var isUseBase = false
    
     @objc public func start(withCompanyID _companyID: String, isUseBase _isUseBase: Bool, account_id _account_id: String? = nil, api_token _api_token: String, email _email: String, phone _phone: String? = nil, url _url: String, port _port: String, name _name: String? = nil, connectionStatus startBlock: UDSStartBlock) {
        
        let hud = MBProgressHUD.showAdded(to: (RootView?.view)!, animated: true)
        hud.mode = MBProgressHUDMode.indeterminate
        hud.label.text = "Loading"
        
        companyID = _companyID
        email = _email
        api_token = _api_token
        port = _port
        urlWithoutPort = _url
        url = "\(_url):\(port)"
        isUseBase = _isUseBase
        if _account_id != nil {
            account_id = _account_id!
        }
        if _name != nil {
            if _name != "" {
                name = _name!
            }
        }
        if _phone != nil {
            if _phone != "" {
                phone = _phone!
            }
        }
        if isUseBase && _account_id != nil {
            let baseView = UDBaseView()
            baseView.usedesk = self
            baseView.url = self.url
            let navController = UDNavigationController(rootViewController: baseView)
            navController.modalPresentationStyle = .fullScreen
            RootView?.present(navController, animated: true)
            hud.hide(animated: true)
        } else {
            if isUseBase && _account_id == nil {
                startBlock(false, "You did not specify account_id")
            } else {
                startWithoutGUICompanyID(companyID: companyID, isUseBase: isUseBase, account_id: account_id, api_token: api_token, email: email, phone: _phone, url: urlWithoutPort, port: port, name: _name, connectionStatus: { success, error in
                    if success {
                        let dialogflowVC : DialogflowView = DialogflowView()
                        dialogflowVC.usedesk = self
                        let navController = UDNavigationController(rootViewController: dialogflowVC)
                        navController.modalPresentationStyle = .fullScreen
                        RootView?.present(navController, animated: true)
                        hud.hide(animated: true)
                    } else {
                        if (error == "noOperators") {
                            let offlineVC = UDOfflineForm(nibName: "UDOfflineForm", bundle: nil)
                            offlineVC.url = self.url
                            offlineVC.usedesk = self
                            let navController = UDNavigationController(rootViewController: offlineVC)
                            navController.modalPresentationStyle = .fullScreen
                            RootView?.present(navController, animated: true)
                            hud.hide(animated: true)
                        }
                    }
                    
                })
                
            }
        }       
    }

    public func sendMessage(_ text: String?) {
        let mess = UseDeskSDKHelp.messageText(text)
        socket!.emit("dispatch", with: mess!)
    }
    
    public func sendMessage(_ text: String?, withFileName fileName: String?, fileType: String?, contentBase64: String?) {
        let mess = UseDeskSDKHelp.message(text, withFileName: fileName, fileType: fileType, contentBase64: contentBase64)
        socket!.emit("dispatch", with: mess!)
    }
    
     @objc public func startWithoutGUICompanyID(companyID _companyID: String, isUseBase _isUseBase: Bool, account_id _account_id: String? = nil, api_token _api_token: String, email _email: String, phone _phone: String? = nil, url _url: String, port _port: String, name _name: String? = nil, connectionStatus startBlock: @escaping UDSStartBlock) {
        
        companyID = _companyID
        email = _email
        
        api_token = _api_token
        port = _port
        url = "\(_url):\(port)"
        isUseBase = _isUseBase
        if _account_id != nil {
            account_id = _account_id!
        }
        if _name != nil {
            if _name != "" {
                name = _name!
            }
        }
        if _phone != nil {
            if _phone != "" {
                phone = _phone!
            }
        }
        let urlAdress = URL(string: url)
        
        let config = ["log": true]
        manager = SocketManager(socketURL: urlAdress!, config: config)
        
        socket = manager!.defaultSocket

        socket!.connect()
        
        socket!.on("connect", callback: { data, ack in
            print("socket connected")
            let token = self.loadToken(for: self.email)
            let arrConfStart = UseDeskSDKHelp.config_CompanyID(self.companyID, email: self.email, phone: self.phone, name: self.name, url: self.url, token: token)
            self.socket!.emit("dispatch", with: arrConfStart!)
        })
        
        socket!.on("error", callback: { data, ack in
            if (self.errorBlock != nil) {
                self.errorBlock!(data)
            }
        })
        socket!.on("disconnect", callback: { data, ack in
            print("socket disconnect")
            let token = self.loadToken(for: self.email)
            let arrConfStart = UseDeskSDKHelp.config_CompanyID(self.companyID, email: self.email, phone: self.phone, name: self.name, url: self.url, token: token)
            self.socket!.emit("dispatch", with: arrConfStart!)
        })
        
        socket!.on("dispatch", callback: { data, ack in
            if data.count == 0 {
                return
            }
            
            self.action_INITED(data)
            
            let no_operators = self.action_INITED_no_operators(data)
            
            if no_operators {
                startBlock(false, "noOperators")
            } else {
            
            let auth_success = self.action_ADD_INIT(data)
            
            if auth_success {
                startBlock(auth_success, "")
            } else {
                startBlock(auth_success, "false inited")
            }
 
            if auth_success && (self.connectBlock != nil) {
                self.connectBlock!(true, nil)
            }
            
            self.action_Feedback_Answer(data)
            
            self.action_ADD_MESSAGE(data)
            }
        })
    }
    
    @objc public func getCollections(connectionStatus baseBlock: @escaping UDSBaseBlock) {
        if isUseBase && account_id != "" {
            DispatchQueue.global(qos: .default).async(execute: {
                       request("https://api.usedesk.ru/support/\(self.account_id)/list?api_token=\(self.api_token)").responseJSON{ responseJSON in
                           switch responseJSON.result {
                           case .success(let value):
                               guard let collections = BaseCollection.getArray(from: value) else {
                                   baseBlock(false, nil, "error parsing")
                                   return }
                               baseBlock(true, collections, "")
                           case .failure(let error):
                               baseBlock(false, nil, error.localizedDescription)
                           }
                       }
                   })
        } else {
            if isUseBase && account_id == "" {
                baseBlock(false, nil, "You did not specify account_id")
            } else {
                baseBlock(false, nil, "You specify isUseBase = false")
            }
        }
    }
    
    @objc public func getArticle(articleID: Int, connectionStatus baseBlock: @escaping UDSArticleBlock) {
        if isUseBase && account_id != "" {
            DispatchQueue.global(qos: .default).async(execute: {                request("https://api.usedesk.ru/support/\(self.account_id)/articles/\(articleID)?api_token=\(self.api_token)").responseJSON{ responseJSON in
                    switch responseJSON.result {
                    case .success(let value):
                        guard let article = Article.get(from: value) else {
                            baseBlock(false, nil, "error parsing")
                            return }
                        baseBlock(true, article, "")
                    case .failure(let error):
                        baseBlock(false, nil, error.localizedDescription)
                    }
                }
            })
        } else {
            if isUseBase && account_id == "" {
                baseBlock(false, nil, "You did not specify account_id")
            } else {
                baseBlock(false, nil, "You specify isUseBase = false")
            }
        }
    }
    
    @objc public func addViewsArticle(articleID: Int, count: Int, connectionStatus connectBlock: @escaping UDSConnectBlock) {
        if isUseBase && account_id != "" {
            DispatchQueue.global(qos: .default).async(execute: {            request("https://api.usedesk.ru/support/\(self.account_id)/articles/\(articleID)/add-views?api_token=\(self.api_token)&count=\(count)").responseJSON{ responseJSON in
                    switch responseJSON.result {
                    case .success( _):
                        connectBlock(true, "")
                    case .failure(let error):
                        connectBlock(false, error.localizedDescription)
                    }
                }
            })
        } else {
            if isUseBase && account_id == "" {
                connectBlock(false, "You did not specify account_id")
            } else {
                connectBlock(false, "You specify isUseBase = false")
            }
        }
    }
    
    @objc public func getSearchArticles(collection_ids:[Int], category_ids:[Int], article_ids:[Int], count: Int = 20, page: Int = 1, query: String, type: TypeArticle = .all, sort: SortArticle = .id, order: OrderArticle = .asc, connectionStatus searchBlock: @escaping UDSArticleSearchBlock) {
        if isUseBase && account_id != "" {
            var url = "https://api.usedesk.ru/support/\(account_id)/articles/list?api_token=\(api_token)"
            var urlForEncode = "&query=\(query)&count=\(count)&page=\(page)"
            switch type {
            case .close:
                urlForEncode += "&type=public"
            case .open:
                urlForEncode += "&type=private"
            default:
                break
            }
            
            switch sort {
            case .id:
                urlForEncode += "&sort=id"
            case .category_id:
                urlForEncode += "&sort=category_id"
            case .created_at:
                urlForEncode += "&sort=created_at"
            case .open:
                urlForEncode += "&sort=public"
            case .title:
                urlForEncode += "&sort=title"
            default:
                break
            }
            
            switch order {
            case .asc:
                urlForEncode += "&order=asc"
            case .desc:
                urlForEncode += "&order=desc"
            default:
                break
            }
            if collection_ids.count > 0 {
                var idsStrings = ""
                urlForEncode += "&collection_ids="
                for id in collection_ids {
                    if idsStrings == "" {
                        idsStrings += "\(id)"
                    } else {
                        idsStrings += ",\(id)"
                    }
                }
                urlForEncode += idsStrings
            }
            if category_ids.count > 0 {
                var idsStrings = ""
                urlForEncode += "&category_ids="
                for id in category_ids {
                    if idsStrings == "" {
                        idsStrings += "\(id)"
                    } else {
                        idsStrings += ",\(id)"
                    }
                }
                urlForEncode += idsStrings
            }
            if article_ids.count > 0 {
                var idsStrings = ""
                urlForEncode += "&article_ids="
                for id in article_ids {
                    if idsStrings == "" {
                        idsStrings += "\(id)"
                    } else {
                        idsStrings += ",\(id)"
                    }
                }
                urlForEncode += idsStrings
            }

            let escapedUrl = urlForEncode.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
            url += escapedUrl ?? ""
            DispatchQueue.global(qos: .default).async(execute: {
                request(url).responseJSON{ responseJSON in
                    switch responseJSON.result {
                    case .success(let value):
                        guard let articles = SearchArticle(from: value) else {
                            searchBlock(false, nil, "error parsing")
                            return }
                        searchBlock(true, articles, "")
                    case .failure(let error):
                        searchBlock(false, nil, error.localizedDescription)
                    }
                }
            })
        } else {
            if isUseBase && account_id == "" {
                searchBlock(false, nil, "You did not specify account_id")
            } else {
                searchBlock(false, nil, "You specify isUseBase = false")
            }
        }
        
    }
    
    func sendOfflineForm(withMessage message: String?, callback resultBlock: @escaping UDSStartBlock) {
        let param = [
            "company_id" : self.companyID,
            "name" : self.name,
            "email" : self.email,
            "message" : message
        ]
        
        DispatchQueue.global(qos: .default).async(execute: {
            let urlStr = "https://secure.usedesk.ru/widget.js/post"
            request(urlStr, method: .post, parameters: param as Parameters).responseJSON{ responseJSON in
                switch responseJSON.result {
                case .success( _):
                    resultBlock(true, nil)
                case .failure(let error):
                    resultBlock(false, error.localizedDescription)
                }
            }
        })
    }
    
    func action_INITED(_ data: [Any]?) {
        print(data)
        let dicServer = data?[0] as? [AnyHashable : Any]
        
        if dicServer?["token"] != nil {
            token = dicServer?["token"] as! String
            save(email, token: token)
        }
        
        let setup = dicServer?["setup"] as? [AnyHashable : Any]
        
        if setup != nil {
            let messages = setup?["messages"] as? [Any]
            historyMess = [AnyHashable]()
            if messages != nil {
                for mess in messages!  {
                    let m: RCMessage? = parseMessageDic(mess as? [AnyHashable : Any])
                    if let aM = m {
                        historyMess.append(aM)
                    }
                }
            }
            //let waitingEmail = Bool(setup?["waitingEmail"] as! Bool )
            
            //if waitingEmail {
            socket!.emit("dispatch", with: UseDeskSDKHelp.dataEmail(email, phone: self.phone, name: self.name)!)
            //}
        }
        
    }
    
    func parseMessageDic(_ mess: [AnyHashable : Any]?) -> RCMessage? {
        let m = RCMessage(text: "", incoming: false)
        
        let createdAt = mess?["createdAt"] as! String
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ru")
        dateFormatter.timeZone = TimeZone(identifier: "Europe/Moscow")
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if dateFormatter.date(from: createdAt) == nil {
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        }
        m.date = dateFormatter.date(from: createdAt)!
        
        m.messageId = Int(mess?["id"] as! Int)
        m.incoming = (mess?["type"] as! String == "client_to_operator") ? false : true
        m.outgoing = !m.incoming
        m.text = mess?["text"] as! String

        if m.incoming {
            let stringsFromButtons = parseMessageFromButtons(text: m.text)
            for stringFromButton in stringsFromButtons {
                let rsButton = buttonFromString(stringButton: stringFromButton)
                if rsButton != nil {
                    m.rcButtons.append(rsButton!)
                }
                m.text = m.text.replacingOccurrences(of: stringFromButton, with: "")
            }
            for index in 0..<m.rcButtons.count {
                let invertIndex = (m.rcButtons.count - 1) - index
                if m.rcButtons[invertIndex].visible {
                    m.text = m.rcButtons[invertIndex].title + " " + m.text
                }
            }
        }        
        
        let payload = mess?["payload"] //as? [AnyHashable : Any]
        
        if payload != nil && (payload is [AnyHashable : Any]){
            let payload1 = mess?["payload"] as! [AnyHashable : Any]
            let avatar = payload1["avatar"]
            if avatar != nil {
                m.avatar = payload1["avatar"] as! String
            }
        }
        
        let fileDic = mess?["file"] as? [AnyHashable : Any]
        if fileDic != nil {
            let file = RCFile()
            file.content = fileDic?["content"] as! String
            file.name = fileDic?["name"] as! String
            file.type = fileDic?["type"] as! String
            m.file = file
            m.type = RC_TYPE_PICTURE
            m.status = RC_STATUS_LOADING
            if (file.type == "image/png") {
                do {
                    if  URL(string: file.content) != nil {
                        let aContent = URL(string: file.content)
                        let aContent1 = try Data(contentsOf: aContent!)
                        m.picture_image = UIImage(data: aContent1)
                        
                    }
                } catch {                    
                }
            }
            
            m.picture_width = Int(0.6 * SCREEN_WIDTH)
            m.picture_height = Int(0.6 * SCREEN_WIDTH)
        }
        
        if payload != nil && (payload is String) {
            m.feedback = true
            m.type = 9
        }

        return m
    }
    //{{button:Возьми дробовик;https://usedesk.ru;blank;show}}
    func parseMessageFromButtons(text: String) -> [String] {
        var isAddingButton: Bool = false
        var characterArrayFromRCButton = [Character]()
        var stringsFromRCButton = [String]()
        if text.count > 2 {
            for index in 0..<text.count - 1 {
                let indexString = text.index(text.startIndex, offsetBy: index)
                let secondIndexString = text.index(text.startIndex, offsetBy: index + 1)
                if isAddingButton {
                    characterArrayFromRCButton.append(text[indexString])
                    if (text[indexString] == "}") && (text[secondIndexString] == "}") {
                        characterArrayFromRCButton.append(text[secondIndexString])
                        isAddingButton = false
                        stringsFromRCButton.append(String(characterArrayFromRCButton))
                        characterArrayFromRCButton = []
                    }
                } else {
                    if (text[indexString] == "{") && (text[secondIndexString] == "{") {
                        characterArrayFromRCButton.append(text[indexString])
                        isAddingButton = true
                    }
                }
            }
        }
        return stringsFromRCButton
    }
    
    func buttonFromString(stringButton: String) -> RCMessageButton? {
        var stringsParameters = [String]()
        var charactersFromParameter = [Character]()
        var index = 9
        var isNameExists = true
        while (index < stringButton.count - 2) && isNameExists {
            let indexString = stringButton.index(stringButton.startIndex, offsetBy: index)
            if stringButton[indexString] != ";" {
                charactersFromParameter.append(stringButton[indexString])
                index += 1
            } else {
                // если первый параметр(имя) будет равно "" то не создавать кнопку
                if (stringsParameters.count == 0) && (charactersFromParameter.count == 0) {
                    isNameExists = false
                } else {
                    stringsParameters.append(String(charactersFromParameter))
                    charactersFromParameter = []
                    index += 1
                }
            }
        }

        if isNameExists && (stringsParameters.count == 3) {
            stringsParameters.append(String(charactersFromParameter))
            let rcButton = RCMessageButton()
            rcButton.title = stringsParameters[0]
            rcButton.url = stringsParameters[1]
            if stringsParameters[3] == "show" {
                rcButton.visible = true
            } else {
                rcButton.visible = false
            }
            return rcButton
        } else {
            return nil
        }
        
    }
    
    func action_INITED_no_operators(_ data: [Any]?) -> Bool {
        
        let dicServer = data?[0] as? [AnyHashable : Any]
        
        if dicServer?["token"] != nil {
            token = dicServer?["token"] as! String
        }
        
        let setup = dicServer?["setup"] as? [AnyHashable : Any]
        
        if setup != nil {
            
            let noOperators = (setup?["noOperators"])

            if noOperators != nil {
                return true
            }
        }
        return false
    }
    
    func action_ADD_INIT(_ data: [Any]?) -> Bool {
        
        let dicServer = data?[0] as? [AnyHashable : Any]
        
        let type = dicServer?["type"] as? String
        if type == nil {
            return false
        }
        if (type == "@@chat/current/INITED") { //ADD_MESSAGE
            return true
        }
        
//        let message = dicServer?["message"] as? [AnyHashable : Any]
//
//        if message != nil {
//            if (message?["chat"] is NSNull) {
//                return true
//            }
//        }
        return false
        
    }
    
    func action_Feedback_Answer(_ data: [Any]?) {
        let dicServer = data?[0] as? [AnyHashable : Any]
        
        let type = dicServer?["type"] as? String
        if type == nil {
            return
        }
        if !(type == "@@chat/current/CALLBACK_ANSWER") {
            return
        }
        
        let answer = dicServer?["answer"] as? [AnyHashable : Any]
        if (feedbackAnswerMessageBlock != nil) {
            feedbackAnswerMessageBlock!(answer?["status"] as! Bool)
        }
        
    }
    
    func action_ADD_MESSAGE(_ data: [Any]?) {
        
        let dicServer = data?[0] as? [AnyHashable : Any]
        
        let type = dicServer?["type"] as? String
        if type == nil {
            return
        }
        if !(type == "@@chat/current/ADD_MESSAGE") {
           // return
        }
        
        if (type == "bot_to_client") {
            
        }
        
        let message = dicServer?["message"] as? [AnyHashable : Any]
        
        if message != nil {
            
            if (message?["chat"] is NSNull) {
                return
            }
            
            let mess: RCMessage? = parseMessageDic(message)
            
            if mess?.feedback != nil && (feedbackMessageBlock != nil) {
                feedbackMessageBlock!(mess)
                return
            }
            if (newMessageBlock != nil) {
                newMessageBlock!(true, mess)
            }
        }
    }
    
    public func sendMessageFeedBack(_ status: Bool) {
        socket!.emit("dispatch", with: UseDeskSDKHelp.feedback(status)!)
    }
    
    func save(_ email: String?, token: String?) {
        UserDefaults.standard.set(token, forKey: email ?? "")
        UserDefaults.standard.synchronize()
    }
    
    func loadToken(for email: String?) -> String? {
        let savedValue = UserDefaults.standard.string(forKey: email ?? "")
        return savedValue
    }
    
    public func releaseChat() {
        socket = manager!.defaultSocket
        socket!.disconnect()
    }
    
}
