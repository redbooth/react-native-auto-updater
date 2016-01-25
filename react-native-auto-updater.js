/**
 * Created by Rahul Jiresal on 01/22/16.
 */

'use strict';

var React = require('react-native');
var RNAUNative = React.NativeModules.ReactNativeAutoUpdater;

type Props = {
  isVisible: boolean;
}

module.exports = {
  jsCodeVersion: function() {
  	return RNAUNative.jsCodeVersion;
  }
};