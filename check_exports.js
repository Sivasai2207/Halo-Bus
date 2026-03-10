const driverController = require('./frontend/college-portal/server/controllers/driverController');
const expected = [
    'getDriverBuses',
    'searchDriverBuses',
    'updateBusLocation',
    'startTrip',
    'endTrip',
    'saveTripHistory',
    'historyUpload',
    'checkProximity',
    'markPickup',
    'markDropoff',
    'getTripAttendance',
    'getBusStudents',
    'getTodayAttendance',
    'notifyStudentAttendance',
    'generateHandoverOTP',
    'verifyHandoverOTP'
];

expected.forEach(fn => {
    if (typeof driverController[fn] !== 'function') {
        console.error(`ERROR: ${fn} is undefined or not a function! (got ${typeof driverController[fn]})`);
    } else {
        console.log(`${fn}: OK`);
    }
});
