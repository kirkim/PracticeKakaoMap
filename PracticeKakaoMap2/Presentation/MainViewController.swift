//
//  MainViewController.swift
//  PracticeKakaoMap2
//
//  Created by 김기림 on 2022/06/12.
//

import UIKit
import CoreLocation
import RxSwift
import RxCocoa
import SnapKit
//import SystemConfiguration

class MainViewController: UIViewController {
    let disposeBag = DisposeBag()
    
    let locationManager = CLLocationManager()
    let mapView = MTMapView()
    let currentLocationButton = UIButton()
    let detailList = UITableView()
    let detailListBackgroundView = DetailListBackgroundView()
    let viewModel = MainViewModel()
    
    init() {
        super.init(nibName: nil, bundle: nil)
        
        mapView.delegate = self
        locationManager.delegate = self
        
        
        attribute()
        layout()
        bind(viewModel)
        let sample = MTMapPOIItem()
        sample.mapPoint = MTMapPoint(geoCoord: MTMapPointGeo(latitude: 37.5674205185068, longitude: 126.977873331336))
        sample.markerType = .redPin
        mapView.addPOIItems([sample])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func bind(_ viewModel: MainViewModel) {
        detailListBackgroundView.bind(viewModel.detailListBackgroundViewModel)
        viewModel.setMapCenter
            .emit(to: mapView.rx.setMapCenterPoint)
            .disposed(by: disposeBag)
        
        viewModel.errorMessage
            .emit(to: self.rx.presentAlert)
            .disposed(by: disposeBag)
        
        viewModel.detailListCellData
            .drive(detailList.rx.items) { tv, row, data in
                let cell = tv.dequeueReusableCell(withIdentifier: "DetailListCell", for: IndexPath(row: row, section: 0)) as! DetailListCell
                cell.setData(data)
                return cell
            }
            .disposed(by: disposeBag)
        
        //데이터를 받아서 맵에 핀을 그려줌
        viewModel.detailListCellData
            .map { $0.compactMap { $0.point } }
            .drive(self.rx.addPOIItems)
            .disposed(by: disposeBag)
        
        viewModel.scrollToSelectedLocation
            .emit(to: self.rx.showSelectedLocation)
            .disposed(by: disposeBag)
        
        detailList.rx.itemSelected
            .map { $0.row }
            .bind(to: viewModel.detailListItemSelected)
            .disposed(by: disposeBag)
        
        self.currentLocationButton.rx.tap
            .bind(to: viewModel.curentLocationButtonTapped)
            .disposed(by: disposeBag)
    }
    
    private func attribute() {
        title = "내 주변 편의점 찾기"
        view.backgroundColor = .white
        mapView.currentLocationTrackingMode = .onWithoutHeadingWithoutMapMoving
        
        currentLocationButton.setImage(UIImage(systemName: "location.fill"), for: .normal)
        currentLocationButton.backgroundColor = .white
        currentLocationButton.layer.cornerRadius = 20
        
        detailList.register(DetailListCell.self, forCellReuseIdentifier: "DetailListCell")
        detailList.separatorStyle = .none
        detailList.backgroundView = detailListBackgroundView
        
        mapView.showCurrentLocationMarker = true
    }
    
    private func layout() {
        [mapView, currentLocationButton, detailList].forEach {
            view.addSubview($0)
        }
        
        mapView.snp.makeConstraints {
            $0.top.leading.trailing.equalTo(view.safeAreaLayoutGuide)
            $0.bottom.equalTo(view.snp.centerY).offset(100)
        }
        
        currentLocationButton.snp.makeConstraints {
            $0.bottom.equalTo(detailList.snp.top).offset(-12)
            $0.leading.equalToSuperview().offset(12)
            $0.width.height.equalTo(40)
        }
        
        detailList.snp.makeConstraints {
            $0.centerX.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(view.safeAreaLayoutGuide).inset(8)
            $0.top.equalTo(mapView.snp.bottom)
        }
    }
}

extension MainViewController: CLLocationManagerDelegate {
 
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways,
                .authorizedWhenInUse,
                .notDetermined:
            return
        default:
            viewModel.mapViewError.accept(MTMapViewError.locationAuthorizationDenied.errorDescription)
            return
        }
    }
}

extension MainViewController: MTMapViewDelegate {
    func mapView(_ mapView: MTMapView!, updateCurrentLocation location: MTMapPoint!, withAccuracy accuracy: MTMapLocationAccuracy) {
#if DEBUG
        viewModel.currentLocation.accept(MTMapPoint(geoCoord: MTMapPointGeo(latitude: 37.394225, longitude: 127.118341)))
#else
        viewModel.currentLocation.accept(loaction)
#endif
    }
    
    // 맵 이동이 끝났을 때
    func mapView(_ mapView: MTMapView!, finishedMapMoveAnimation mapCenterPoint: MTMapPoint!) {
        viewModel.mapCenterPoint.accept(mapCenterPoint)
    }
    
    // 핀 클릭마다 데이터전달
    func mapView(_ mapView: MTMapView!, selectedPOIItem poiItem: MTMapPOIItem!) -> Bool {
        viewModel.selectPOIItem.accept(poiItem)
        return false
    }
    
    func mapView(_ mapView: MTMapView!, failedUpdatingCurrentLocationWithError error: Error!) {
        viewModel.mapViewError.accept(error.localizedDescription)
    }
}

// rx extension custom
//extension Reactive where Base: MTMapView {
//    var setMapCenterPoint: Binder<MTMapPoint> {
//        return Binder(base) { base, point in
//            base.setMapCenter(point, animated: true)
//        }
//    }
//}

extension Reactive where Base: MainViewController {
    var presentAlert: Binder<String> {
        return Binder(base) { base, message in
            let alertController = UIAlertController(title: "문제가 발생했어요", message: message, preferredStyle: .alert)
            let action = UIAlertAction(title: "확인", style: .default, handler: nil)
            alertController.addAction(action)
            base.present(alertController, animated: true, completion: nil)
        }
    }
    
    var showSelectedLocation: Binder<Int> {
        return Binder(base) { base, row in
            let indexPath = IndexPath(row: row, section: 0)
            base.detailList.selectRow(at: indexPath, animated: true, scrollPosition: .top)
        }
    }
    
    var addPOIItems: Binder<[MTMapPoint]> {
        return Binder(base) { base, points in
            let items = points
                .enumerated()
                .map { offset, point -> MTMapPOIItem in
                    let mapPOIItem = MTMapPOIItem()
                    mapPOIItem.mapPoint = point
                    mapPOIItem.markerType = .bluePin
//                    mapPOIItem.showAnimationType = .springFromGround
                    mapPOIItem.tag = offset
                    
                    return mapPOIItem
                }
            
            base.mapView.removeAllPOIItems()
            base.mapView.addPOIItems(items)
        }
    }
}
