using UnityEditor.Rendering.Universal.Internal;
using UnityEngine;
using UnityEngine.Rendering;

namespace UnityEditor.Rendering.Universal
{
    internal static class NewSurfaceShaderDropdownItem
    {
        static readonly string defaultNewClassName = "CustomSurfaceShader.surfaceshader";

        [MenuItem("Assets/Create/Shader/Universal Render Pipeline/Surface Shader", priority = CoreUtils.assetCreateMenuPriority1)]
        internal static void CreateNewSurfaceShader()
        {
            Debug.Log("CreateNewSurfaceShader");
            string templatePath = AssetDatabase.GUIDToAssetPath("5323a4b224869d94b86448be902203c6");
            ProjectWindowUtil.CreateScriptAssetFromTemplateFile(templatePath, defaultNewClassName);
        }
    }
}
