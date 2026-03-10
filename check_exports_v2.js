const driverController = require('./frontend/college-portal/server/controllers/driverController');
const notificationController = require('./frontend/college-portal/server/controllers/notificationController');
const authController = require('./frontend/college-portal/server/controllers/authController');

const check = (name, controller, expected) => {
    console.log(`--- Checking ${name} ---`);
    expected.forEach(fn => {
        if (typeof controller[fn] !== 'function') {
            console.error(`ERROR: ${fn} is undefined or not a function! (got ${typeof controller[fn]})`);
        } else {
            console.log(`${fn}: OK`);
        }
    });
};

check('driverController', driverController, [
    'getDriverBuses', 'searchDriverBuses', 'updateBusLocation', 'startTrip', 'endTrip',
    'saveTripHistory', 'historyUpload', 'checkProximity', 'markPickup', 'markDropoff',
    'getTripAttendance', 'getBusStudents', 'getTodayAttendance', 'notifyStudentAttendance',
    'generateHandoverOTP', 'verifyHandoverOTP'
]);

check('notificationController', notificationController, [
    'sendStopEventNotification', 'sendTripEndedNotification'
]);

check('authController', authController, [
    'loginUser', 'registerOwner', 'googleLogin', 'getFirebaseHealth',
    'getCollegeBySlug', 'searchColleges', 'getMe', 'studentLogin', 'studentSetPassword'
]);
