using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class RotateObject : MonoBehaviour
{
	public GameObject m_SceneObject;
	public float m_RotationSpeed;
	float m_Angle;

	void Start()
	{
		m_Angle = 0.0f;
	}

    // Update is called once per frame
    void Update()
    {
    	if (m_SceneObject == null)
    	{
    		Debug.Log("No game object attached to " + this);
    		return;
    	}

    	m_Angle = Mathf.Repeat(Time.time * m_RotationSpeed, 360.0f);
    	float angleRadian = Mathf.Deg2Rad * m_Angle;
    	m_SceneObject.transform.position = new Vector3(Mathf.Cos(angleRadian), 1.0f, Mathf.Sin(angleRadian));
    }
}
