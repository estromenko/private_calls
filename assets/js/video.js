export async function makeCall(liveSocket, peerConnection) {
  const mediaConstrains = { video: true, audio: true }
  const stream = await navigator.mediaDevices.getUserMedia(mediaConstrains)

  const localVideo = document.querySelector("#own-video")
  localVideo.srcObject = stream
  await localVideo.play()

  stream.getTracks().forEach((track) => {
    peerConnection.addTrack(track, stream)
  })

  const offer = await peerConnection.createOffer()
  await peerConnection.setLocalDescription(offer)

  liveSocket.pushEvent("rtc_message", { message: { offer } })
}

export async function handleVideo(liveSocket, peerConnection) {
  const video = document.querySelector("#remote-video")

  peerConnection.addEventListener("track", async (event) => {
    if (video.srcObject?.id === event.streams[0].id) {
      return
    }
    video.srcObject = event.streams[0]
    await video.play()
  })

  window.addEventListener("phx:rtc_message", async (event) => {
    if (event.detail.answer) {
      const remoteDesc = new RTCSessionDescription(event.detail.answer)
      await peerConnection.setRemoteDescription(remoteDesc)
    }

    if (event.detail.candidate) {
      await peerConnection.addIceCandidate(event.detail.candidate)
    }

    if (event.detail.offer) {
      const remoteDesc = new RTCSessionDescription(event.detail.offer)
      peerConnection.setRemoteDescription(remoteDesc)
      const answer = await peerConnection.createAnswer()
      await peerConnection.setLocalDescription(answer)
      liveSocket.pushEvent("rtc_message", { message: { answer } })
    }
  })

  peerConnection.addEventListener("icecandidate", (event) => {
    if (event.candidate) {
      liveSocket.pushEvent("rtc_message", { message: { candidate: event.candidate } })
    }
  })

  peerConnection.addEventListener("iceconnectionstatechange", (_event) => {
    if (peerConnection.iceConnectionState == "disconnected") {
      video.srcObject = null
    }
  })
}
