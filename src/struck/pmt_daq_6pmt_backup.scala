#!/usr/bin/env daqcore-scala-fadc

// Syntax: seg-bege-daq.scala ADC_HOSTNAME OUTPUT_BASENAME MEAS_TIME_IN_SEC

import scala.async.Async.{async, await}
import scala.concurrent.{Future, Promise}, scala.concurrent.duration._
import akka.actor.{Cancellable}
import daqcore.actors._, daqcore.io._, daqcore.devices._, daqcore.util._, daqcore.data._, daqcore.defaults._
import daqcore.util.fileops._

import SIS3316.dataTypes._
import SIS3316.SIS3316Impl._

def exit() = { daqcoreSystem.shutdown(); daqcoreSystem.awaitTermination(); sys.exit(0); }

object logger extends Logging
logger.info("Ready")


//if (args.size != 3) throw new RuntimeException("Invalid number of command line arguments")

val adcHostname = "gelab-fadc08"
val outputBasename = "test-measurement"
val measurementTime = 5

logger.info("ADC hostname: $adcHostname")
logger.info("Output basename: $outputBasename")
logger.info("Measurement time: $measurementTime s")

val adc = SIS3316(s"vme-sis3316://$adcHostname", "adc")


def configureADC_allch(): Unit = {
  adc.trigger_extern_enabled_set(allChannels --> false)
  adc.trigger_intern_enabled_set(allChannels --> false)
  adc.event_format_set(allChannels --> EventFormat())
  adc.bank_fill_threshold_stop_set(allChannels --> false)
  adc.getSync().get
}

//Channels START
val trig_pmt = 1
val other_pmts = Ch(2, 3, 4, 5, 6)
val all_pmts = Ch(trig_pmt) ++ other_pmts

val peakTime = 2
val gapTime  = 2
val nPreTrig = 128
val nSamples = 256

def configureADC_hpge(): Unit = {
  adc.trigger_intern_gen_set(trig_pmt --> true)
  adc.trigger_intern_feedback_set(trig_pmt-->true)
  adc.trigger_extern_enabled_set(all_pmts --> true)

  adc.input_invert_set(trig_pmt --> true)
  adc.input_invert_set(other_pmts --> true)

  adc.trigger_gate_window_length_set(all_pmts --> 128)

  adc.trigger_threshold_set(all_pmts --> 42)
  adc.trigger_cfd_set(all_pmts --> CfdCtrl.CDF50Percent)
  adc.trigger_peakTime_set(all_pmts --> 2)
  adc.trigger_gapTime_set(all_pmts --> 2)

  adc.energy_peakTime_set(all_pmts --> peakTime)
  adc.energy_gapTime_set(all_pmts --> gapTime)

  adc.energy_tau_table_set(all_pmts --> 0)
  adc.energy_tau_factor_set(all_pmts --> 0)

  adc.event_format_set(all_pmts -->
    EventFormat(
      save_maw_values = None,
      save_energy = true,
      save_ft_maw = true,
      save_acc_78 = false,
      save_ph_acc16 = true,
      nSamples = nSamples,
      nMAWValues = 128
    )
  )

  adc.nsamples_pretrig_set(all_pmts --> nPreTrig)
  adc.nmaw_pretrig_set(all_pmts --> nPreTrig)

  adc.bank_fill_threshold_stop_set(all_pmts --> false)

  adc.getSync().get
  val rawEventDataSize = adc.event_format_get().get vMap {_.rawEventDataSize}
  adc.bank_fill_threshold_nbytes_set(rawEventDataSize vMap {4 * _})
  adc.getSync().get
}


def configureADC(): Unit = {
  configureADC_allch()
  configureADC_hpge()
}


def printStatus() {
  println(s"ADC identity: ${adc.identity.get}, serial number ${adc.serNo.get}")
  println(s"ADC temperature: ${adc.internalTemperature.get} Â°C")
  println(s"Buffer count: ${adc.buffer_counter_get.get}")
}


def stopAfter(delay: FiniteDuration): (Future[Unit], Cancellable) = {
  val p = Promise[Unit]()
  val s = scheduleOnce(delay) {
    async {
      if (await(adc.capture_enabled_get)) {
        adc.stopCapture() onComplete {_ => p.success({})}
      }
    }
  }
  (p.future, s)
}

def runFor(time: FiniteDuration): (Future[Unit], Cancellable) = {
  adc.startCapture()
  stopAfter(time)
}

configureADC()

adc.raw_output_file_basename_set(outputBasename)
//adc.props_output_file_basename_set(outputBasename)

val (stopped, runCancellable) = runFor(measurementTime.seconds)
adc.getSync().get
println(adc.raw_output_file_name_get.get)

stopped onComplete {_ => exit() }
